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
end
