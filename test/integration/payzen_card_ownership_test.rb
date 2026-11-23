# frozen_string_literal: true

require 'test_helper'

class PayzenCardOwnershipTest < ActionDispatch::IntegrationTest
  include WebMock::API

  setup do
    WebMock.reset_executed_requests!
    @schedule = payment_schedules('payment_schedule_13')
    @owner = @schedule.user
    @other_member = payment_schedules('payment_schedule_12').user

    Setting.set('payzen_endpoint', 'https://api.payzen.eu')
    Setting.set('payzen_username', 'test_user')
    Setting.set('payzen_password', 'test_password')
  end

  test 'schedule card policy allows its owner and staff but not another member' do
    assert PaymentSchedulePolicy.new(@owner, @schedule).update_card?
    assert PaymentSchedulePolicy.new(User.admins.first, @schedule).update_card?
    assert_not PaymentSchedulePolicy.new(@other_member, @schedule).update_card?
    @other_member.add_role(:manager)
    assert PaymentSchedulePolicy.new(@other_member, @schedule).update_card?
  end

  test 'card replacement denies a non-owner before contacting PayZen' do
    login_as(@other_member, scope: :user)
    provider_request = stub_token_update

    request_replacement

    assert_response :forbidden
    assert_not_requested provider_request
  ensure
    remove_request_stub(provider_request) if provider_request
  end

  test 'card replacement still issues a form token to the owner' do
    login_as(@owner, scope: :user)
    provider_request = stub_token_update

    request_replacement

    assert_response :success
    assert_equal 'test-form-token', json_response(response.body)[:formToken]
    assert_requested provider_request, times: 1
  ensure
    remove_request_stub(provider_request) if provider_request
  end

  private

  def request_replacement
    post '/api/payzen/update_token',
         params: { payment_schedule_id: @schedule.id }.to_json, headers: default_headers
  end

  def stub_token_update
    stub_request(:post, 'https://api.payzen.eu/api-payment/V4/Token/Update/')
      .with(basic_auth: %w[test_user test_password])
      .to_return(body: '{"status":"SUCCESS","answer":{"formToken":"test-form-token"}}')
  end
end
