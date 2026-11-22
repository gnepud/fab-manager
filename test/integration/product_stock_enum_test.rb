# frozen_string_literal: true

require 'test_helper'

class ProductStockEnumTest < ActionDispatch::IntegrationTest
  setup do
    @product = Product.find(11)
    login_as(User.find_by(username: 'admin'), scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  %w[internal external].each do |stock_type|
    test "unknown reason for #{stock_type} stock returns a validation error" do
      assert_invalid_movement({ stock_type: stock_type, reason: 'qa_unknown_reason', quantity: 1 }, /reason/i)
    end

    test "invalid enum rejects the whole update including a valid #{stock_type} movement" do
      valid = { stock_type: stock_type, reason: 'inward_stock', quantity: 3 }
      [{ stock_type: stock_type, reason: 'qa_unknown_reason', quantity: 1 },
       { stock_type: 'qa_unknown_stock', reason: 'sold', quantity: 1 }].each do |invalid|
        original_stock = @product.reload.stock.deep_dup
        assert_no_difference 'ProductStockMovement.count' do
          update_stock([valid, invalid])
          assert_response :unprocessable_entity
        end
        assert_equal original_stock, @product.reload.stock
      end
    end

    test "valid incoming and outgoing reasons retain signed #{stock_type} history" do
      [['inward_stock', 3], ['sold', -2]].each do |reason, delta|
        original_stock = @product.reload.stock.deep_dup
        assert_difference 'ProductStockMovement.count', 1 do
          update_stock([{ stock_type: stock_type, reason: reason, quantity: delta.abs }])
          assert_response :ok
        end
        expected_stock = original_stock.merge(stock_type => original_stock[stock_type] + delta)
        assert_equal expected_stock, @product.reload.stock
        movement = @product.product_stock_movements.order(:id).last
        assert_equal stock_type, movement.stock_type
        assert_equal reason, movement.reason
        assert_equal delta, movement.quantity
        assert_equal expected_stock[stock_type], movement.remaining_stock
      end
    end
  end

  %w[inward_stock sold].each do |reason|
    test "unknown stock type for #{reason} returns a validation error" do
      assert_invalid_movement({ stock_type: 'qa_unknown_stock', reason: reason, quantity: 1 }, /stock type/i)
    end
  end

  test 'missing and blank enum values return validation errors' do
    [nil, ''].each do |value|
      assert_invalid_movement({ stock_type: value, reason: 'inward_stock', quantity: 1 }, /stock type/i)
      assert_invalid_movement({ stock_type: 'external', reason: value, quantity: 1 }, /reason/i)
    end
  end

  test 'an empty movement list leaves stock and history unchanged' do
    original_stock = @product.stock.deep_dup
    assert_no_difference 'ProductStockMovement.count' do
      update_stock([])
      assert_response :ok
    end
    assert_equal original_stock, @product.reload.stock
  end

  private

  def assert_invalid_movement(movement, field)
    original_stock = @product.reload.stock.deep_dup
    assert_no_difference 'ProductStockMovement.count' do
      update_stock([movement])
      assert_response :unprocessable_entity
    end
    errors = JSON.parse(response.body).join(' ')
    assert_match field, errors
    assert_includes errors, I18n.t('errors.messages.inclusion')
    assert_equal original_stock, @product.reload.stock
  end

  def update_stock(movements)
    put "/api/products/#{@product.id}",
        params: { product: { amount: @product.amount / 100.0, product_stock_movements_attributes: movements } }.to_json,
        headers: default_headers
  end
end
