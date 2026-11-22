# frozen_string_literal: true

require 'test_helper'

module Reservations; end

class Reservations::LockedAvailabilityTest < ActionDispatch::IntegrationTest
  setup do
    @member = User.members.without_subscription.first
    @space = Space.first
    start_at = 4.days.from_now.change(hour: 12, min: 0, sec: 0)
    @availability = Availability.create!(available_type: 'space', start_at: start_at, end_at: start_at + 1.hour,
                                         spaces: [@space], lock: true)
    @slot = @availability.slots.create!(start_at: start_at, end_at: start_at + 1.hour)
    Slots::PlacesCacheService.refresh(@slot)
    Price.where(priceable: @space).update_all(amount: 0)
    login_as(@member, scope: :user)
  end

  test 'members cannot pay for a locked availability' do
    balance = @member.wallet.amount
    assert_no_difference ['Reservation.count', 'Invoice.count', 'SlotsReservation.count'] do
      confirm
      assert_equal 422, response.status, response.body
      assert_includes json_response(response.body)[:availability], 'This availability is locked'
    end
    assert_equal balance, @member.wallet.reload.amount
  end

  test 'members cannot create a cart item for a locked availability' do
    order = Cart::FindOrCreateService.new(@member).call(nil)
    post '/api/cart/create_item', params: { order_token: order.token }.merge(item)
    assert_equal 422, response.status, response.body
    assert_includes response.body, 'This availability is locked'
  end

  test 'cart validation rejects an availability locked after adding it' do
    @availability.update!(lock: false)
    order = Cart::FindOrCreateService.new(@member).call(nil)
    post '/api/cart/create_item', params: { order_token: order.token }.merge(item)
    assert_equal 201, response.status, response.body
    resource = json_response(response.body)
    cart_item = resource[:type].classify.constantize.find(resource[:id])
    Cart::AddItemService.new.call(order, cart_item, 1)
    @availability.update!(lock: true)
    post '/api/cart/validate', params: { order_token: order.token }
    assert_equal 200, response.status, response.body
    assert_includes response.body, 'This availability is locked'
  end

  test 'members can book unlocked availabilities' do
    @availability.update!(lock: false)
    confirm
    assert_equal 201, response.status, response.body
  end

  test 'administrators and managers can book locked availabilities for members' do
    manager = User.members.where.not(id: @member.id).first
    manager.add_role(:manager)
    [User.with_role(:admin).first, manager].each do |operator|
      login_as(operator, scope: :user)
      confirm
      assert_equal 201, response.status, response.body
    end
  end

  private

  def item
    { reservation: { reservable_type: 'Space', reservable_id: @space.id,
                     slots_reservations_attributes: [{ slot_id: @slot.id, offered: false }] } }
  end

  def confirm
    post '/api/local_payment/confirm_payment', params: { customer_id: @member.id, items: [item] }.to_json,
                                               headers: default_headers
  end
end
