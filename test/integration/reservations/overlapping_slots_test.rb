# frozen_string_literal: true

require 'test_helper'

module Reservations; end

class Reservations::OverlappingSlotsTest < ActionDispatch::IntegrationTest
  setup do
    @member = User.members.without_subscription.first
    @machine = Machine.find(6)
    @space = Space.first
    @start = 3.days.from_now.change(hour: 12, min: 0, sec: 0)
    @machine_slot = make_slot(@machine, @start, @start + 1.hour)
    @space_slot = make_slot(@space, @start + 30.minutes, @start + 90.minutes)
    Price.where(priceable: [@machine, @space]).find_each { |price| price.update!(amount: 0) }
    Setting.set('book_overlapping_slots', false)
    Setting.set('overlapping_categories', 'training_reservations,machine_reservations,space_reservations,events_reservations')
    login_as(@member, scope: :user)
  end

  test 'existing machine reservation prevents an overlapping space booking' do
    reserve_machine
    assert_no_difference ['Reservation.count', 'Invoice.count'] do
      confirm(item(@space, @space_slot))
      assert_equal 422, response.status, response.body
      assert_includes json_response(response.body)[:slot], I18n.t('cart_item_validation.overlapping')
    end
  end

  test 'overlapping items in one cart are rejected atomically' do
    assert_no_difference ['Reservation.count', 'Invoice.count'] do
      confirm(item(@machine, @machine_slot), item(@space, @space_slot))
      assert_equal 422, response.status, response.body
    end
  end

  test 'overlapping slots within one reservation are rejected' do
    other = make_slot(@space, @start, @start + 1.hour)
    reservation = item(@space, @space_slot)
    reservation[:reservation][:slots_reservations_attributes] << { slot_id: other.id }
    confirm(reservation)
    assert_equal 422, response.status, response.body
  end

  test 'existing reservation of the same reservable and slot is not excluded' do
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
    confirm(item(@space, @space_slot))
    assert_equal 422, response.status, response.body
  end

  test 'equal starts and contained intervals overlap' do
    reserve_machine
    [[@start, @start + 1.hour], [@start - 1.hour, @start + 2.hours],
     [@start + 10.minutes, @start + 50.minutes], [@start - 30.minutes, @start + 30.minutes]].each do |start_at, end_at|
      @space_slot.update!(start_at: start_at, end_at: end_at)
      confirm(item(@space, @space_slot))
      assert_equal 422, response.status, response.body
    end
  end

  test 'unvalidated event registrations are ignored' do
    event_reservation = reserve_event
    sr = event_reservation.slots_reservations.first
    sr.update!(is_valid: false, canceled_at: nil)
    sr.slot.update!(start_at: @start, end_at: @start + 1.hour)
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
  end

  test 'validated event registrations prevent overlaps' do
    event_reservation = reserve_event
    sr = event_reservation.slots_reservations.first
    sr.update!(is_valid: true, canceled_at: nil)
    sr.slot.update!(start_at: @start, end_at: @start + 1.hour)
    confirm(item(@space, @space_slot))
    assert_equal 422, response.status, response.body
  end

  test 'touching boundaries are not overlapping' do
    reserve_machine
    @space_slot.update!(start_at: @machine_slot.end_at, end_at: @machine_slot.end_at + 1.hour)
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
  end

  test 'members may book more tickets for an event they already registered to' do
    event = free_event(Event.first)
    confirm(event_item(event))
    assert_equal 201, response.status, response.body
    confirm(event_item(event))
    assert_equal 201, response.status, response.body
  end

  test 'same cart cannot contain multiple bookings for the same event' do
    event = free_event(Event.first)
    assert_no_difference ['Reservation.count', 'Invoice.count'] do
      confirm(event_item(event), event_item(event))
      assert_equal 422, response.status, response.body
    end
  end

  test 'same event slot cannot appear twice within one reservation' do
    event = free_event(Event.first)
    reservation = event_item(event)
    reservation[:reservation][:slots_reservations_attributes] << { slot_id: event.availability.slots.first.id }
    assert_no_difference ['Reservation.count', 'Invoice.count'] do
      confirm(reservation)
      assert_equal 422, response.status, response.body
    end
  end

  test 'an existing different event still prevents an overlapping event booking' do
    event, other = Event.order(:id).limit(2).map { |record| free_event(record) }
    confirm(event_item(other))
    assert_equal 201, response.status, response.body
    confirm(event_item(event))
    assert_equal 422, response.status, response.body
  end

  test 'same cart bookings for different overlapping events are rejected' do
    event, other = Event.order(:id).limit(2).map { |record| free_event(record) }
    confirm(event_item(event), event_item(other))
    assert_equal 422, response.status, response.body
  end

  test 'an existing space reservation still prevents an overlapping event booking' do
    event = free_event(Event.first)
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
    confirm(event_item(event))
    assert_equal 422, response.status, response.body
  end

  test 'enabled overlapping permits existing reservations and same cart overlaps' do
    Setting.set('book_overlapping_slots', true)
    confirm(item(@machine, @machine_slot), item(@space, @space_slot))
    assert_equal 201, response.status, response.body
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
  end

  test 'canceled reservations do not prevent booking' do
    reserve_machine.slots_reservations.first.update!(canceled_at: Time.current)
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
  end

  test 'unselected overlap categories do not prevent booking' do
    reserve_machine
    Setting.set('overlapping_categories', 'space_reservations')
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
  end

  test 'an empty overlap category list permits booking' do
    reserve_machine
    Setting.set('overlapping_categories', '')
    confirm(item(@space, @space_slot))
    assert_equal 201, response.status, response.body
  end

  test 'administrators and managers may override overlaps for a member' do
    reserve_machine
    manager = User.members.where.not(id: @member.id).first
    manager.add_role(:manager)
    [User.with_role(:admin).first, manager].each do |operator|
      login_as(operator, scope: :user)
      confirm(item(@space, @space_slot))
      assert_equal 201, response.status, response.body
    end
  end

  private

  def free_event(event)
    event.update!(amount: 0)
    event.availability.slots.first.update!(start_at: @start, end_at: @start + 1.hour)
    event
  end

  def event_item(event)
    reservation = item(event, event.availability.slots.first)
    reservation[:reservation][:nb_reserve_places] = 1
    reservation
  end

  def reserve_event
    event = Event.first
    Reservation.create!(reservable: event, statistic_profile: @member.statistic_profile, nb_reserve_places: 1,
                        slots_reservations_attributes: [{ slot_id: event.availability.slots.first.id }])
  end

  def make_slot(reservable, start_at, end_at)
    type = reservable.is_a?(Machine) ? 'machines' : 'space'
    availability = Availability.create!(available_type: type, start_at: start_at, end_at: end_at,
                                        (reservable.is_a?(Machine) ? :machines : :spaces) => [reservable])
    slot = availability.slots.create!(start_at: start_at, end_at: end_at)
    Slots::PlacesCacheService.refresh(slot)
    slot
  end

  def reserve_machine
    confirm(item(@machine, @machine_slot))
    assert_equal 201, response.status, response.body
    Reservation.last
  end

  def item(reservable, slot)
    { reservation: { reservable_type: reservable.class.name, reservable_id: reservable.id,
                     slots_reservations_attributes: [{ slot_id: slot.id }] } }
  end

  def confirm(*items)
    post '/api/local_payment/confirm_payment', params: { customer_id: @member.id, items: items }.to_json,
                                               headers: default_headers
  end
end
