# frozen_string_literal: true

require 'test_helper'

class OrderUnsupportedStateTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.find(5)
    login_as(User.find_by(username: 'admin'), scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  (%w[paid payment_failed cart unknown] + [nil, '']).each do |target|
    test "unsupported target #{target.inspect} is rejected from every source state" do
      Order::ALL_STATES.each do |source|
        @order.update!(state: source)
        %i[en fr].each do |locale|
          original_attributes = @order.reload.attributes
          counts = ['OrderActivity.count', 'Notification.count', 'ProductStockMovement.count', 'Invoice.count', 'WalletTransaction.count']

          assert_no_difference counts do
            update_state(target, locale)
            assert_response :unprocessable_entity
          end

          assert_equal [I18n.t('errors.messages.invalid_order_state', locale: locale)], JSON.parse(response.body)
          assert_equal original_attributes, @order.reload.attributes
        end
      end
    end
  end

  %w[in_progress ready canceled delivered refunded].each do |target|
    test "supported target #{target} still succeeds from paid" do
      assert_difference '@order.order_activities.count', 1 do
        update_state(target)
        assert_response :ok
      end

      assert_equal target, @order.reload.state
      assert_equal target, @order.order_activities.order(:id).last.activity_type
    end
  end

  private

  def update_state(target, locale = :en)
    patch "/api/orders/#{@order.id}?locale=#{locale}", params: { order: { state: target } }.to_json, headers: default_headers
  end
end
