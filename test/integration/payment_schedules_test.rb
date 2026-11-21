# frozen_string_literal: true

require 'test_helper'

class PaymentSchedulesTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.friendly.find('pjproudhon')
    login_as(@user, scope: :user)
  end

  test "should get user's schedules" do
    get payment_schedules_url
    assert_response :success

    assert_equal @user.invoicing_profile.payment_schedules.count, json_response(response.body).length
  end

  test 'should report the amount due after wallet credit for the first cheque only' do
    login_as(User.with_role(:admin).first, scope: :user)
    schedule = payment_schedules('payment_schedule_12')
    schedule.update!(payment_method: 'check', wallet_amount: 6_200)
    first, second = schedule.ordered_items.first(2)
    [first, second].each { |item| item.update!(amount: 10_000, state: 'pending', payment_method: nil) }

    post '/api/payment_schedules/list', params: { query: { page: 1, size: 20 } }, as: :json
    assert_response :success

    items = json_response(response.body).find { |entry| entry[:id] == schedule.id }.fetch(:items).index_by { |item| item[:id] }
    assert_equal [100.0, 100.0], [items[first.id][:amount], items[second.id][:amount]]
    assert_equal 38.0, items[first.id][:amount_due]
    assert_equal 100.0, items[second.id][:amount_due]
  end
end
