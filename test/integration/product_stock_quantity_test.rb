# frozen_string_literal: true

require 'test_helper'

class ProductStockQuantityTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.find(11)
    login_as(User.find_by(username: 'admin'), scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'negative quantities cannot reverse incoming or outgoing movements' do
    %w[sold inward_stock].each do |reason|
      assert_invalid_quantity(-3, reason)
    end
  end

  test 'zero fractional missing and non numeric quantities are rejected' do
    [0, 1.5, '2.5', nil, '', 'abc'].each do |quantity|
      assert_invalid_quantity(quantity, 'sold')
    end
  end

  test 'invalid quantity rolls back all movements in the product update' do
    original_stock = @product.stock.deep_dup
    assert_no_difference 'ProductStockMovement.count' do
      update_stock([{ stock_type: 'external', reason: 'inward_stock', quantity: 5 },
                    { stock_type: 'external', reason: 'sold', quantity: -3 }])
      assert_response :unprocessable_entity
    end
    assert_equal original_stock, @product.reload.stock
  end

  test 'positive integer quantities retain signed movement history' do
    [['sold', 3, -3], ['inward_stock', '3', 3]].each do |reason, quantity, delta|
      original_stock = @product.reload.stock['external']
      assert_difference 'ProductStockMovement.count', 1 do
        update_stock([{ stock_type: 'external', reason: reason, quantity: quantity }])
        assert_response :ok
      end
      assert_equal original_stock + delta, @product.reload.stock['external']
      movement = @product.product_stock_movements.order(:id).last
      assert_equal delta, movement.quantity
      assert_equal original_stock + delta, movement.remaining_stock
    end
  end

  private

  def update_stock(movements)
    patch "/api/products/#{@product.id}",
          params: { product: { amount: @product.amount / 100.0, product_stock_movements_attributes: movements } }.to_json,
          headers: default_headers
  end

  def assert_invalid_quantity(quantity, reason)
    original_stock = @product.reload.stock.deep_dup
    assert_no_difference 'ProductStockMovement.count' do
      update_stock([{ stock_type: 'external', reason: reason, quantity: quantity }])
      assert_response :unprocessable_entity
    end
    assert_match(/quantity/i, JSON.parse(response.body).join(' '))
    assert_equal original_stock, @product.reload.stock
  end
end
