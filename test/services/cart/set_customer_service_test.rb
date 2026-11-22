# frozen_string_literal: true

require 'test_helper'

class SetCustomerServiceTest < ActiveSupport::TestCase
  setup do
    @admin = User.find_by(username: 'admin')
    @pjproudhon = User.find_by(username: 'pjproudhon')
  end

  test 'admin update the customer of an anonymous cart' do
    order = Order.find_by(token: '4bB96D-MlqJGBr5T8eui-g1666690417460')
    service = Cart::SetCustomerService.new(@admin)
    service.call(order, @pjproudhon)
    assert_equal @pjproudhon, order.user
    assert_equal @admin, order.operator_profile.user
  end

  test 'admin cannot update the customer of a paid cart' do
    order = Order.find_by(token: 'ttG9U892Bu0gbu8OnJkwTw1664892253183')
    service = Cart::SetCustomerService.new(@admin)
    service.call(order, @pjproudhon)
    assert_not_equal @pjproudhon, order.user
    assert_not_equal @admin, order.operator_profile.user
  end

  test 'member cannot update the customer himself' do
    order = Order.find_by(token: '4bB96D-MlqJGBr5T8eui-g1666690417460')
    service = Cart::SetCustomerService.new(@pjproudhon)
    service.call(order, @pjproudhon)
    assert_nil order.statistic_profile_id
    assert_nil order.operator_profile_id
  end

  test 'all plan based reservation types refresh their customer context' do
    customer = users(:user2)
    subscription = Subscription.create!(statistic_profile: @pjproudhon.statistic_profile, plan: Plan.find(2))
    order = customer_cart(customer)
    items = [
      CartItem::MachineReservation.new(reservable: Machine.find(1)),
      CartItem::SpaceReservation.new(reservable: Space.find(1)),
      CartItem::TrainingReservation.new(reservable: Training.find(1))
    ]
    items.each do |item|
      item.assign_attributes(customer_profile: customer.invoicing_profile, operator_profile: @admin.invoicing_profile,
                             plan: Plan.find(1), new_subscription: true)
      item.save!(context: [])
      Cart::AddItemService.new.call(order, item)
    end
    Cart::SetCustomerService.new(@admin).call(order, @pjproudhon)
    items.each do |item|
      assert_equal @pjproudhon, item.reload.customer
      assert_equal subscription.plan, item.plan
      assert_not item.new_subscription
      assert_equal @admin, item.operator
    end
  end

  test 'selected subscription and pack are preserved without assigning an operator profile' do
    customer = users(:user2)
    order = customer_cart(customer)
    items = [CartItem::Subscription.new(plan: Plan.find(1)), CartItem::PrepaidPack.new(prepaid_pack: PrepaidPack.find(1))]
    items.each do |item|
      item.customer_profile = customer.invoicing_profile
      item.save!(context: [])
      Cart::AddItemService.new.call(order, item)
    end
    Cart::SetCustomerService.new(@admin).call(order, @pjproudhon)
    items.each { |item| assert_equal @pjproudhon, item.reload.customer }
    assert_equal Plan.find(1), items.first.plan
    assert_equal PrepaidPack.find(1), items.last.prepaid_pack
  end

  test 'free extension targets the new customers subscription' do
    customer = users(:user2)
    previous = Subscription.create!(statistic_profile: customer.statistic_profile, plan: Plan.find(1))
    current = Subscription.create!(statistic_profile: @pjproudhon.statistic_profile, plan: Plan.find(2))
    order = customer_cart(customer)
    extension = CartItem::FreeExtension.new(customer_profile: customer.invoicing_profile, subscription: previous,
                                            new_expiration_date: 1.year.from_now)
    extension.save!(context: [])
    Cart::AddItemService.new.call(order, extension)
    Cart::SetCustomerService.new(@admin).call(order, @pjproudhon)
    assert_equal @pjproudhon, extension.reload.customer
    assert_equal current, extension.subscription
    assert_equal 0, order.reload.total
  end

  test 'event tickets and products retain their selections when the customer changes' do
    customer = users(:user2)
    order = customer_cart(customer)
    event = CartItem::EventReservation.new(event: Event.first, normal_tickets: 2,
                                           customer_profile: customer.invoicing_profile, operator_profile: @admin.invoicing_profile)
    event.save!(context: [])
    Cart::AddItemService.new.call(order, event)
    product = Product.first
    line = order.order_items.create!(orderable: product, quantity: 1, amount: product.amount)
    Cart::SetCustomerService.new(@admin).call(order, @pjproudhon)
    assert_equal @pjproudhon, event.reload.customer
    assert_equal @admin, event.operator
    assert_equal 2, event.normal_tickets
    assert_equal product.amount, line.reload.amount
    assert_equal product, line.orderable
  end

  private

  def customer_cart(customer)
    Order.create!(token: SecureRandom.hex, state: 'cart', statistic_profile: customer.statistic_profile,
                  operator_profile: @admin.invoicing_profile)
  end
end
