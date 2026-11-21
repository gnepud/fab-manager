# frozen_string_literal: true

require 'test_helper'

module Reservations; end

class Reservations::MoveEventTest < ActionDispatch::IntegrationTest
  setup do
    login_as(User.admins.first, scope: :user)
    @source = events(:event_1)
    @destination = events(:event_2)
    @destination.availability.update!(start_at: 1.week.from_now, end_at: 1.week.from_now + 2.hours)
  end

  test 'moving serialized mixed-price tickets preserves tickets and transfers capacity' do
    reservation = Reservation.create!(statistic_profile: User.members.first.statistic_profile,
                                      reservable: @source, nb_reserve_places: 1,
                                      tickets_attributes: [{ event_price_category_id: event_price_categories(:one).id, booked: 1 }])
    reservation.slots_reservations.create!(slot: @source.availability.slots.first)
    @source.update_nb_free_places
    @source.save!
    [@source, @destination].each { |event| Slots::PlacesCacheService.refresh(event.availability.slots.first) }
    ticket = reservation.tickets.first

    get "/api/reservations/#{reservation.id}", headers: default_headers
    assert_response :success
    payload = JSON.parse(response.body)
    get "/api/events/#{@source.id}", headers: default_headers
    assert_response :success
    destination = JSON.parse(response.body)['recurrence_events'].find { |event| event['id'] == @destination.id }
    payload['reservable_id'] = destination['id']
    payload['slots_reservations_attributes'].first['slot_id'] = destination['slot_id']

    assert_no_difference 'Ticket.count' do
      put "/api/reservations/#{reservation.id}", params: { reservation: payload }.to_json, headers: default_headers
      assert_response :success
    end

    assert_equal [[ticket.id, ticket.event_price_category_id, 1]], reservation.reload.tickets.pluck(:id, :event_price_category_id, :booked)
    assert_equal 2, reservation.total_booked_seats
    assert_equal @destination.availability.slots.first.id, reservation.slots_reservations.first.slot_id
    assert_equal 10, @source.reload.nb_free_places
    assert_equal 8, @destination.reload.nb_free_places
    assert_equal 0, @source.availability.slots.first.reload.reserved_places(@source)
    assert_equal 2, @destination.availability.slots.first.reload.reserved_places(@destination)
  end

  test 'moving a standard-only reservation transfers capacity without creating tickets' do
    reservation = Reservation.create!(statistic_profile: User.members.first.statistic_profile,
                                      reservable: @source, nb_reserve_places: 1)
    slot_reservation = reservation.slots_reservations.create!(slot: @source.availability.slots.first)

    assert_no_difference 'Ticket.count' do
      put "/api/reservations/#{reservation.id}", params: {
        reservation: { reservable_id: @destination.id, tickets_attributes: [],
                       slots_reservations_attributes: [{ id: slot_reservation.id, slot_id: @destination.availability.slots.first.id }] }
      }.to_json, headers: default_headers
      assert_response :success
    end
    assert_equal 10, @source.reload.nb_free_places
    assert_equal 9, @destination.reload.nb_free_places
  end

  test 'invalid ticket update does not move the reservation or duplicate tickets' do
    reservation = Reservation.create!(statistic_profile: User.members.first.statistic_profile,
                                      reservable: @source, nb_reserve_places: 1,
                                      tickets_attributes: [{ event_price_category_id: event_price_categories(:one).id, booked: 1 }])
    ticket = reservation.tickets.first

    assert_no_difference 'Ticket.count' do
      put "/api/reservations/#{reservation.id}", params: {
        reservation: { reservable_id: @destination.id, tickets_attributes: [{ id: ticket.id, booked: 0 }] }
      }.to_json, headers: default_headers
      assert_response :unprocessable_entity
    end
    assert_equal @source.id, reservation.reload.reservable_id
    assert_equal 1, ticket.reload.booked
  end

  test 'moving a reservation preserves pending cart holds on both occurrences' do
    reservation = Reservation.create!(statistic_profile: User.members.first.statistic_profile,
                                      reservable: @source, nb_reserve_places: 2)
    source_slot = @source.availability.slots.first
    destination_slot = @destination.availability.slots.first
    slot_reservation = reservation.slots_reservations.create!(slot: source_slot)
    @source.save!
    [@source, @destination].each do |event|
      slot = event.availability.slots.first
      Slots::PlacesCacheService.refresh(slot)
      Slots::PlacesCacheService.change_places(slot, 'Event', event.id, 1)
    end

    put "/api/reservations/#{reservation.id}", params: {
      reservation: { reservable_id: @destination.id,
                     slots_reservations_attributes: [{ id: slot_reservation.id, slot_id: destination_slot.id }] }
    }.to_json, headers: default_headers
    assert_response :success

    assert_equal 1, source_slot.reload.reserved_places(@source)
    assert_equal 3, destination_slot.reload.reserved_places(@destination)
    assert_not_includes source_slot.reserved_users([@source]), reservation.user.id
    assert_includes destination_slot.reserved_users([@destination]), reservation.user.id
    assert_equal 10, @source.reload.nb_free_places
    assert_equal 8, @destination.reload.nb_free_places
  end
end
