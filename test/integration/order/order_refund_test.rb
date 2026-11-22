# frozen_string_literal: true

require 'test_helper'

class OrderRefundTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.find(5)
    login_as(User.find_by(username: 'admin'), scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'failed payment cannot be refunded and returns a translated error without side effects' do
    @order.update!(state: 'payment_failed')

    counts = ['OrderActivity.count', 'Notification.count', 'ProductStockMovement.count', 'Invoice.count', 'WalletTransaction.count']
    assert_no_difference counts do
      patch "/api/orders/#{@order.id}?locale=fr", params: { order: { state: 'refunded' } }.to_json, headers: default_headers
      assert_response :unprocessable_entity
    end

    assert_equal ['Impossible de modifier le statut de cette commande depuis son statut actuel.'], JSON.parse(response.body)
    assert_equal 'payment_failed', @order.reload.state
  end

  test 'paid and canceled orders can still be marked refunded' do
    %w[paid canceled].each do |state|
      @order.update!(state: state)

      assert_difference '@order.order_activities.count', 1 do
        patch "/api/orders/#{@order.id}", params: { order: { state: 'refunded' } }.to_json, headers: default_headers
      end

      assert_response :ok
      assert_equal 'refunded', @order.reload.state
    end
  end

  test 'cart refunded and delivered orders remain non refundable' do
    %w[cart refunded delivered].each do |state|
      @order.update!(state: state)

      assert_no_difference 'OrderActivity.count' do
        patch "/api/orders/#{@order.id}", params: { order: { state: 'refunded' } }.to_json, headers: default_headers
      end

      assert_response :unprocessable_entity
      assert_equal ['This order cannot be updated from its current state.'], JSON.parse(response.body)
      assert_equal state, @order.reload.state
    end
  end
end
