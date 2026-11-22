# frozen_string_literal: true

require 'test_helper'

class SetCustomerAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    @admin = users(:user1)
    @member = users(:user2)
    @manager = users(:user5)
    @manager.add_role(:manager)
    @other_manager = users(:user3)
    @other_manager.add_role(:manager)
    @order = Order.create!(token: SecureRandom.hex, state: 'cart', statistic_profile: @member.statistic_profile,
                           operator_profile: @manager.invoicing_profile, total: 900)
    @item = @order.order_items.create!(orderable: Product.first, quantity: 1, amount: 900)
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'manager cannot select an admin as customer' do
    assert_customer_protected(@admin)
  end

  test 'manager cannot select another manager as customer' do
    assert_customer_protected(@other_manager)
  end

  test 'manager can select a member as customer' do
    select_customer(users(:user4))

    assert_response :ok
    assert_equal users(:user4), @order.reload.user
    assert_equal @manager.invoicing_profile, @order.operator_profile
  end

  test 'manager can select themselves as customer' do
    select_customer(@manager)

    assert_response :ok
    assert_equal @manager, @order.reload.user
  end

  test 'admins can select admins and managers as customers' do
    @order.update!(operator_profile: @admin.invoicing_profile)
    login_as(@admin, scope: :user)
    [@admin, @other_manager].each do |customer|
      select_customer(customer)

      assert_response :ok
      assert_equal customer, @order.reload.user
    end
  end

  test 'member cannot change the customer even to themselves' do
    login_as(@member, scope: :user)
    assert_customer_protected(@member)
  end

  test 'manager cannot select privileged customers for an empty anonymous cart' do
    @order.order_items.destroy_all
    @order.update!(statistic_profile: nil, operator_profile: nil, total: 0)
    assert_customer_protected(@admin)
  end

  test 'unknown customer leaves the cart unchanged' do
    original = @order.reload.attributes
    assert_raises(ActiveRecord::RecordNotFound) { select_customer(User.maximum(:id) + 1) }

    assert_equal original, @order.reload.attributes
  end

  private

  def select_customer(customer)
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: customer.is_a?(User) ? customer.id : customer }
  end

  def assert_customer_protected(customer)
    original_order = @order.reload.attributes
    original_items = @order.order_items.reload.map(&:attributes)
    select_customer(customer)

    assert_response :forbidden
    assert_empty response.body
    assert_equal original_order, @order.reload.attributes
    assert_equal original_items, @order.order_items.reload.map(&:attributes)
  end
end
