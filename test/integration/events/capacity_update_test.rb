# frozen_string_literal: true

require 'test_helper'

module Events; end

class Events::CapacityUpdateTest < ActionDispatch::IntegrationTest
  test 'capacity increase and date move after two free bookings' do
    admin = User.with_role(:admin).first
    member = User.find_by!(username: 'pdurand')
    login_as(admin, scope: :user)
    date = 2.months.from_now.to_date
    attrs = {
      title: 'Capacity update', description: 'An event with additional places',
      category_id: Category.first.id, event_type: 'standard',
      nb_total_places: 3, amount: 0, all_day: 'true',
      start_date: date.to_s, end_date: (date + 1.day).to_s
    }
    post '/api/events', params: { event: attrs }.to_json, headers: default_headers
    assert_equal 201, response.status, response.body
    event = Event.find(json_response(response.body)[:id])
    slot = event.availability.slots.first
    # Transactional fixtures defer after_create_commit, unlike a real HTTP request.
    Slots::PlacesCacheService.refresh(slot)

    [2, 1].each do |seats|
      login_as(member, scope: :user)
      post '/api/local_payment/confirm_payment', params: {
        customer_id: member.id,
        items: [{ reservation: {
          reservable_id: event.id, reservable_type: 'Event', nb_reserve_places: seats,
          slots_reservations_attributes: [{ slot_id: slot.id, offered: false }]
        } }]
      }.to_json, headers: default_headers
      assert_equal 201, response.status, response.body
      assert_equal 3 - event.reservations.sum(:nb_reserve_places), event.reload.nb_free_places
      assert_equal 3 - event.nb_free_places, slot.reload.reserved_places(event)
    end

    login_as(admin, scope: :user)
    put "/api/events/#{event.id}", params: {
      event: attrs.merge(nb_total_places: 5, amount: 10, start_date: (date + 2.days).to_s,
                         end_date: (date + 3.days).to_s), edit_mode: 'single'
    }.to_json, headers: default_headers
    assert_equal 200, response.status, response.body
    assert_equal 1, json_response(response.body)[:updated], response.body
    assert_equal 5, event.reload.nb_total_places
    assert_equal 2, event.nb_free_places
    assert_equal 1000, event.amount
    assert_equal (date + 2.days), slot.reload.start_at.to_date
    assert_equal slot.id, event.availability.slots.first.id

    booking = {
      customer_id: member.id,
      items: [{ reservation: {
        reservable_id: event.id, reservable_type: 'Event', nb_reserve_places: 1,
        slots_reservations_attributes: [{ slot_id: slot.id, offered: false }]
      } }]
    }
    post '/api/local_payment/confirm_payment', params: booking.to_json, headers: default_headers
    assert_equal 201, response.status, response.body
    assert_equal 1, event.reload.nb_free_places
    assert_equal 4, slot.reload.reserved_places(event)
  end
end
