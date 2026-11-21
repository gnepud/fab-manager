# frozen_string_literal: true

require 'test_helper'

class OrdersIndexTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.find(5)
  end

  test 'index exposes wallet payments in currency units to members and admins' do
    @order.update!(paid_total: 0, wallet_amount: 12_000)

    [@order.statistic_profile.user, User.find_by(username: 'admin')].each do |user|
      login_as(user, scope: :user)
      get '/api/orders', headers: default_headers

      assert_response :success
      order = json_response(response.body)[:data].find { |item| item[:id] == @order.id }
      assert_not_nil order
      assert_equal 120.0, order[:wallet_amount]
      assert_equal 0.0, order[:paid_total]
      logout(:user)
    end
  end
end
