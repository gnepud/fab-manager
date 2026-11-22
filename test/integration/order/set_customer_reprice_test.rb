# frozen_string_literal: true

require 'test_helper'

class SetCustomerRepriceTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:user1)
    @alice = users(:user2)
    @bob = User.members.without_subscription.where.not(id: @alice.id).first
    @bob.update!(group: @alice.group)
    Subscription.create!(statistic_profile: @alice.statistic_profile, plan: Plan.find(1))
    @space = Space.find(1)
    @space.prices.find_by!(group_id: @alice.group_id, plan_id: 1).update!(amount: 800)
    @space.prices.find_by!(group_id: @alice.group_id, plan_id: nil).update!(amount: 1500)
    start_at = 8.days.from_now.change(hour: 12, min: 0, sec: 0)
    availability = Availability.create!(available_type: 'space', start_at: start_at, end_at: start_at + 1.hour,
                                        spaces: [@space], nb_total_places: 10)
    slot = availability.slots.create!(start_at: start_at, end_at: start_at + 1.hour)
    Slots::PlacesCacheService.refresh(slot)
    @order = Order.create!(token: SecureRandom.hex, statistic_profile: @alice.statistic_profile,
                           operator_profile: @admin.invoicing_profile, state: 'cart')
    @item = CartItem::SpaceReservation.new(customer_profile: @alice.invoicing_profile, operator_profile: @admin.invoicing_profile,
                                           reservable: @space, plan: @alice.subscribed_plan, new_subscription: false,
                                           cart_item_reservation_slots_attributes: [{ slot_id: slot.id }])
    @item.save!(context: [])
    Cart::AddItemService.new.call(@order, @item)
    assert_equal 800, @order.reload.total
    login_as(@admin, scope: :user)
  end

  test 'changing to an unsubscribed customer removes the previous plan and reprices' do
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 200, response.status, response.body
    assert_equal 1500, @order.reload.total
    assert_nil @item.reload.plan
    assert_equal @bob, @item.customer
    assert_not @item.new_subscription
    post '/api/cart/validate', params: { order_token: @order.token }
    assert_equal 200, response.status
    assert_empty json_response(response.body)[:details].first[:errors]
  end

  test 'changing to an admin in another group uses the new group without the old plan' do
    @admin.update!(group: Group.find(2))
    @space.prices.find_by!(group_id: @admin.group_id, plan_id: nil).update!(amount: 1700)
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @admin.id }
    assert_equal 200, response.status, response.body
    assert_equal 1700, @order.reload.total
    assert_nil @item.reload.plan
    assert_equal @admin, @item.customer
  end

  test 'changing to a subscriber uses their active plan' do
    Subscription.create!(statistic_profile: @bob.statistic_profile, plan: Plan.find(2))
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 200, response.status, response.body
    assert_equal Plan.find(2), @item.reload.plan
    assert_equal 1800, @order.reload.total
    assert_not @item.new_subscription
  end

  test 'expired subscriptions do not supply a plan' do
    subscription = Subscription.create!(statistic_profile: @bob.statistic_profile, plan: Plan.find(2))
    subscription.update!(expiration_date: 1.day.ago)
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 200, response.status, response.body
    assert_nil @item.reload.plan
    assert_equal 1500, @order.reload.total
  end

  test 'a subscription being purchased still supplies the reservation plan' do
    pending = CartItem::Subscription.new(plan: Plan.find(2), customer_profile: @alice.invoicing_profile)
    pending.save!(context: [])
    Cart::AddItemService.new.call(@order, pending)
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 200, response.status, response.body
    assert_equal pending.plan, @item.reload.plan
    assert @item.new_subscription
    assert_equal @bob, pending.reload.customer
    assert_equal 1800 + pending.plan.amount, @order.reload.total
  end

  test 'incompatible selected subscription returns a readable error and rolls back the customer change' do
    pending = CartItem::Subscription.new(plan: Plan.find(1), customer_profile: @alice.invoicing_profile)
    pending.save!(context: [])
    Cart::AddItemService.new.call(@order, pending)
    @bob.update!(group: Group.find(2))
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 422, response.status, response.body
    assert_includes response.body, I18n.t('cart_item_validation.plan_group', GROUP: pending.plan.group.name)
    assert_equal @alice, @order.reload.user
    assert_equal @alice, @item.reload.customer
    assert_equal @alice, pending.reload.customer
  end

  test 'an extension cannot be transferred to a customer without a subscription' do
    extension = CartItem::FreeExtension.new(customer_profile: @alice.invoicing_profile, subscription: @alice.subscription,
                                            new_expiration_date: 1.year.from_now)
    extension.save!(context: [])
    Cart::AddItemService.new.call(@order, extension)
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 422, response.status, response.body
    assert_includes response.body, I18n.t('errors.messages.blank')
    assert_equal @alice, @order.reload.user
    assert_equal @alice.subscription, extension.reload.subscription
    assert_equal @alice, @item.reload.customer
  end

  test 'extension dates must remain valid for the new subscription' do
    Subscription.create!(statistic_profile: @bob.statistic_profile, plan: Plan.find(2))
    extension = CartItem::FreeExtension.new(customer_profile: @alice.invoicing_profile, subscription: @alice.subscription,
                                            new_expiration_date: @alice.subscription.expired_at + 1.day)
    extension.save!(context: [])
    Cart::AddItemService.new.call(@order, extension)
    put '/api/cart/set_customer', params: { order_token: @order.token, user_id: @bob.id }
    assert_equal 422, response.status, response.body
    assert_includes response.body, I18n.t('cart_items.must_be_after_expiration')
    assert_equal @alice, @order.reload.user
    assert_equal @alice.subscription, extension.reload.subscription
  end
end
