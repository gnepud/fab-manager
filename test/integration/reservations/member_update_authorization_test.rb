# frozen_string_literal: true

require 'test_helper'

module Reservations; end

class Reservations::MemberUpdateAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    @member = users(:user2)
    @admin = users(:user1)
    @manager = users(:user5)
    @manager.add_role :manager unless @manager.manager?
    @source = Event.find(1)
    @destination = Event.find(2)
    @source_slot = @source.availability.slots.first
    @destination_slot = @destination.availability.slots.first
    @source.availability.update!(start_at: 2.days.from_now, end_at: 2.days.from_now + 4.hours)
    @destination.availability.update!(start_at: 3.days.from_now, end_at: 3.days.from_now + 4.hours)
    @source_slot.update!(start_at: @source.availability.start_at, end_at: @source.availability.end_at)
    @destination_slot.update!(start_at: @destination.availability.start_at, end_at: @destination.availability.end_at)
    @source.update!(nb_free_places: @source.nb_total_places)
    @destination.update!(nb_free_places: @destination.nb_total_places)
    Setting.set('booking_move_enable', true)
    Setting.set('booking_move_delay', 24)
  end

  teardown do
    Warden.test_reset!
    Setting.set('booking_move_enable', false)
    Setting.set('booking_move_delay', 24)
  end

  test 'member cannot change booked places on a paid reservation' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: {
      reservation: { nb_reserve_places: 8 }
    }.to_json, headers: default_headers

    assert_response :success
    assert_equal 1, reservation.reload.nb_reserve_places
    assert_equal 9, @source.reload.nb_free_places
  end

  test 'member cannot mark a paid reservation offered' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: {
      reservation: { slots_reservations_attributes: [{ id: reservation.slots_reservations.first.id, offered: true }] }
    }.to_json, headers: default_headers

    assert_response :success
    assert_equal false, reservation.reload.slots_reservations.first.offered
  end

  test 'member cannot move a reservation to an arbitrary slot' do
    reservation = create_reservation
    arbitrary_slot = Slot.find(9)
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: {
      reservation: { slots_reservations_attributes: [{ id: reservation.slots_reservations.first.id, slot_id: arbitrary_slot.id }] }
    }.to_json, headers: default_headers

    assert_response :forbidden
    assert_equal @source_slot.id, reservation.reload.slots_reservations.first.slot_id
  end

  test 'member cannot move a reservation when booking moves are disabled' do
    reservation = create_reservation
    Setting.set('booking_move_enable', false)
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: move_params(reservation, @destination), headers: default_headers

    assert_response :forbidden
    assert_equal @source.id, reservation.reload.reservable_id
  end

  test 'member cannot move a reservation within the booking move delay' do
    reservation = create_reservation
    @source_slot.update!(start_at: 1.hour.from_now, end_at: 5.hours.from_now)
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: move_params(reservation, @destination), headers: default_headers

    assert_response :forbidden
    assert_equal @source.id, reservation.reload.reservable_id
  end

  test 'member can move an event reservation to another occurrence' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: move_params(reservation, @destination), headers: default_headers

    assert_response :success
    assert_equal @destination.id, reservation.reload.reservable_id
    assert_equal @destination_slot.id, reservation.slots_reservations.first.reload.slot_id
    assert_equal 10, @source.reload.nb_free_places
    assert_equal 9, @destination.reload.nb_free_places
  end

  test 'member cannot change tickets or reservable type in a serialized reservation' do
    reservation = create_reservation
    ticket = reservation.tickets.create!(event_price_category: event_price_categories(:one), booked: 1)
    login_as(@member, scope: :user)
    get reservation_path(reservation), headers: default_headers
    payload = JSON.parse(response.body)
    payload['reservable_type'] = 'Machine'
    payload['tickets_attributes'].first['booked'] = 8

    put reservation_path(reservation), params: { reservation: payload }.to_json, headers: default_headers

    assert_response :success
    assert_equal 'Event', reservation.reload.reservable_type
    assert_equal 1, ticket.reload.booked
  end

  test 'member cannot add a new slot reservation' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    assert_no_difference 'SlotsReservation.count' do
      put reservation_path(reservation), params: {
        reservation: { slots_reservations_attributes: [{ slot_id: @destination_slot.id }] }
      }.to_json, headers: default_headers
      assert_response :forbidden
    end
  end

  test 'member cannot update a slot reservation belonging to another reservation' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: {
      reservation: { slots_reservations_attributes: [{ id: slots_reservations(:one).id, slot_id: @destination_slot.id }] }
    }.to_json, headers: default_headers

    assert_response :forbidden
  end

  test 'member cannot bypass slot validation with repeated slot reservation ids' do
    reservation = create_reservation
    slot_reservation = reservation.slots_reservations.first
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: {
      reservation: { slots_reservations_attributes: [
        { id: slot_reservation.id, slot_id: @source_slot.id },
        { id: slot_reservation.id, slot_id: Slot.find(9).id }
      ] }
    }.to_json, headers: default_headers

    assert_response :forbidden
    assert_equal @source_slot.id, slot_reservation.reload.slot_id
  end

  test 'member cannot move a canceled slot reservation' do
    reservation = create_reservation
    reservation.slots_reservations.first.update_column(:canceled_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: move_params(reservation, @destination), headers: default_headers

    assert_response :forbidden
    assert_equal @source.id, reservation.reload.reservable_id
  end

  test 'member cannot move to an event outside the recurrence' do
    reservation = create_reservation
    @destination.update!(recurrence_id: nil)
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: move_params(reservation, @destination), headers: default_headers

    assert_response :forbidden
  end

  test 'member cannot move to an event without enough free places for all tickets' do
    reservation = create_reservation
    reservation.tickets.create!(event_price_category: event_price_categories(:one), booked: 1)
    @destination.update!(nb_total_places: 1)
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: move_params(reservation, @destination), headers: default_headers

    assert_response :forbidden
  end

  test 'member cannot change event without moving to its slot' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: { reservation: { reservable_id: @destination.id } }.to_json, headers: default_headers

    assert_response :forbidden
  end

  test 'member cannot move to a missing slot' do
    reservation = create_reservation
    login_as(@member, scope: :user)

    put reservation_path(reservation), params: {
      reservation: { slots_reservations_attributes: [{ id: reservation.slots_reservations.first.id, slot_id: nil }] }
    }.to_json, headers: default_headers

    assert_response :forbidden
  end

  %i[admin manager].each do |role|
    test "#{role} can still edit reservation fields" do
      reservation = create_reservation
      user = role == :admin ? @admin : @manager
      login_as(user, scope: :user)

      put reservation_path(reservation), params: {
        reservation: {
          nb_reserve_places: 2,
          slots_reservations_attributes: [{ id: reservation.slots_reservations.first.id, offered: true }]
        }
      }.to_json, headers: default_headers

      assert_response :success
      assert_equal 2, reservation.reload.nb_reserve_places
      assert_equal true, reservation.slots_reservations.first.offered
    end
  end

  private

  def create_reservation
    login_as(@admin, scope: :user)
    post '/api/local_payment/confirm_payment', params: {
      customer_id: @member.id,
      items: [{ reservation: { reservable_id: @source.id, reservable_type: 'Event', nb_reserve_places: 1,
                               slots_reservations_attributes: [{ slot_id: @source_slot.id }] } }]
    }.to_json, headers: default_headers
    assert_response :created
    reservation = Reservation.last
    assert_operator reservation.original_invoice.total, :>, 0
    reservation
  end

  def reservation_path(reservation)
    "/api/reservations/#{reservation.id}"
  end

  def move_params(reservation, event)
    {
      reservation: {
        reservable_id: event.id,
        slots_reservations_attributes: [{ id: reservation.slots_reservations.first.id, slot_id: event.availability.slots.first.id }]
      }
    }.to_json
  end
end
