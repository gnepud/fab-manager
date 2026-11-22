# frozen_string_literal: true

require 'test_helper'

class PayzenConfirmationTest < ActionDispatch::IntegrationTest
  include WebMock::API

  setup do
    @user = User.members.first
    login_as(@user, scope: :user)
    Setting.set('payment_gateway', 'payzen')
  end

  test 'confirm payment with payzen after a refused card attempt' do
    attempts = [
      { status: 'UNPAID', detailedStatus: 'REFUSED' },
      { status: 'PAID', detailedStatus: 'AUTHORISED' }
    ]

    assert_difference({ 'Invoice.count' => 1, 'Subscription.count' => 1 }) do
      confirm_payzen_order(attempts)
      assert_response :created
    end
  end

  test 'do not confirm a payzen order without a single unambiguous paid attempt' do
    refused = { status: 'UNPAID', detailedStatus: 'REFUSED' }
    paid = { status: 'PAID', detailedStatus: 'AUTHORISED' }
    pending = { status: 'RUNNING', detailedStatus: 'WAITING_AUTHORISATION' }

    [[], [refused], [pending, paid], [paid, paid]].each do |attempts|
      assert_no_difference ['Invoice.count', 'Subscription.count'] do
        confirm_payzen_order(attempts)
        assert_response :unprocessable_entity
      end
    end
  end

  private

  def confirm_payzen_order(attempts)
    order_id = 'payzen-card-attempts'
    plan = Plan.find_by!(group_id: @user.group.id, type: 'Plan')
    stub_request(:post, 'https://api.payzen.eu/api-payment/V4/Order/Get/')
      .with(body: { orderId: order_id, operationType: 'DEBIT' })
      .to_return(status: 200, body: { status: 'SUCCESS', answer: { transactions: attempts } }.to_json)

    post '/api/payzen/confirm_payment',
         params: { order_id: order_id, cart_items: { items: [{ subscription: { plan_id: plan.id } }] } }.to_json,
         headers: default_headers
  end
end
