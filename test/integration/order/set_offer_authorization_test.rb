# frozen_string_literal: true

require 'test_helper'

class SetOfferAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.with_role(:admin).first
    @alice = User.find(2)
    @bob = User.find(3)
    @product = Product.find_by(slug: 'panneaux-de-mdf')
    @order = Order.create!(token: GenerateTokenService.new.call(Order), state: 'cart', total: 0,
                           statistic_profile: @admin.statistic_profile, operator_profile: @admin.invoicing_profile)
    Cart::AddItemService.new.call(@order, @product, 1)
    @order.order_items.first.update!(is_offered: false)
    login_as(@admin, scope: :user)
  end

  test 'admin cannot offer to himself when customer id is omitted' do
    assert_refused_offer(true)
  end

  test 'admin cannot offer to himself with a forged customer id' do
    assert_refused_offer(true, customer_id: @alice.id)
  end

  test 'admin cannot offer to himself with his real customer id' do
    assert_refused_offer(true, customer_id: @admin.id)
  end

  test 'member cannot revoke another customers offer with its cart token' do
    member_order
    login_as(@bob, scope: :user)
    assert_refused_offer(false)
  end

  test 'member cannot grant an offer to another customers cart' do
    member_order
    login_as(@bob, scope: :user)
    assert_refused_offer(true, customer_id: @bob.id)
  end

  test 'customer may revoke an offer on her own cart' do
    member_order
    login_as(@alice, scope: :user)
    set_offer(false)
    assert_equal 200, response.status, response.body
    assert_not @order.order_items.first.reload.is_offered
    assert_equal @product.amount, @order.reload.total
  end

  test 'administrators and managers may offer items to another customer' do
    member_order
    @bob.add_role(:manager)
    [@admin, @bob].each do |operator|
      login_as(operator, scope: :user)
      set_offer(true, customer_id: operator.id)
      assert_equal 200, response.status, response.body
      assert @order.order_items.first.reload.is_offered
      assert_equal 0, @order.reload.total
    end
  end

  test 'anonymous callers cannot revoke a customers offer' do
    member_order
    logout(:user)
    assert_refused_offer(false)
  end

  private

  def member_order
    @order = Cart::FindOrCreateService.new(@admin, @alice).call(nil)
    Cart::AddItemService.new.call(@order, @product, 1)
    Cart::SetOfferService.new.call(@order, @product, true)
  end

  def assert_refused_offer(offered, **params)
    total = @order.reload.total
    previous = @order.order_items.first.is_offered
    set_offer(offered, **params)
    assert_equal 403, response.status, response.body
    assert_equal previous, @order.order_items.first.reload.is_offered
    assert_equal total, @order.reload.total
  end

  def set_offer(offered, **params)
    put '/api/cart/set_offer', params: {
      order_token: @order.token, orderable_type: 'Product', orderable_id: @product.id, is_offered: offered
    }.merge(params).to_json, headers: default_headers
  end
end
