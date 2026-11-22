# frozen_string_literal: true

require 'test_helper'

module Reservations; end

class Reservations::CartCapacityTest < ActionDispatch::IntegrationTest
  setup do
    @member = User.members.without_subscription.first
    @machine = Machine.find(6)
    start_at = 4.days.from_now.change(hour: 12, min: 0, sec: 0)
    @availability = Availability.create!(available_type: 'machines', start_at: start_at, end_at: start_at + 1.hour,
                                         machines: [@machine])
    @slot = @availability.slots.create!(start_at: start_at, end_at: start_at + 1.hour)
    Slots::PlacesCacheService.refresh(@slot)
    Price.where(priceable: @machine).find_each { |price| price.update!(amount: 0) }
    login_as(@member, scope: :user)
    @order = Cart::FindOrCreateService.new(@member).call(nil)
    post '/api/cart/create_item', params: {
      order_token: @order.token,
      reservation: { reservable_type: 'Machine', reservable_id: @machine.id,
                     slots_reservations_attributes: [{ slot_id: @slot.id }] }
    }
    assert_equal 201, response.status, response.body
    resource = json_response(response.body)
    cart_item = resource[:type].classify.constantize.find(resource[:id])
    Cart::AddItemService.new.call(@order, cart_item, 1)
    assert @slot.reload.full?
  end

  test 'last place held by the cart remains valid for store checkout' do
    post '/api/cart/validate', params: { order_token: @order.token }
    assert_equal 200, response.status, response.body
    assert_empty json_response(response.body)[:details].first[:errors]
  end

  test 'a lock still invalidates the carts own last place' do
    @availability.update!(lock: true)
    post '/api/cart/validate', params: { order_token: @order.token }
    assert_includes response.body, I18n.t('cart_item_validation.locked')
  end

  test 'another reservation exceeding capacity invalidates the held place' do
    other = User.members.where.not(id: @member.id).first
    Reservation.create!(reservable: @machine, statistic_profile: other.statistic_profile,
                        slots_reservations_attributes: [{ slot_id: @slot.id }])
    post '/api/cart/validate', params: { order_token: @order.token }
    assert_includes response.body, I18n.t('cart_item_validation.reserved')
  end

  test 'new cart items cannot take a place held by another cart item' do
    post '/api/cart/create_item', params: {
      order_token: @order.token,
      reservation: { reservable_type: 'Machine', reservable_id: @machine.id,
                     slots_reservations_attributes: [{ slot_id: @slot.id }] }
    }
    assert_equal 422, response.status, response.body
    assert_includes response.body, I18n.t('cart_item_validation.full')
  end
end
