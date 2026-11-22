# frozen_string_literal: true

require 'test_helper'

class MoveTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    travel_to Time.zone.parse('2026-10-24 12:00:00')
    @member = users(:user2)
    @machine = Machine.find(1)
    @availability = @machine.availabilities.first
    Setting.set('booking_move_enable', true)
    Setting.set('booking_move_delay', 24)
    @original = build_slot(48.hours.from_now)
    reservation = Reservation.create!(statistic_profile: @member.statistic_profile, reservable: @machine, reservation_context_id: 1)
    @booking = SlotsReservation.create!(slot: @original, reservation: reservation)
    login_as(@member, scope: :user)
  end

  teardown do
    Warden.test_reset!
    travel_back
  end

  test 'member cannot move to a full slot of the same machine' do
    target = build_slot(72.hours.from_now)
    reservation = Reservation.create!(statistic_profile: users(:user3).statistic_profile, reservable: @machine, reservation_context_id: 1)
    SlotsReservation.create!(slot: target, reservation: reservation)
    assert_refused(target.id)
  end

  test 'member cannot move to a past slot' do
    assert_refused(build_slot(1.hour.ago).id)
  end

  test 'member cannot move within the move delay' do
    assert_refused(build_slot(23.hours.from_now).id)
  end

  test 'member cannot move to a different machine' do
    @availability = Availability.create!(start_at: 72.hours.from_now, end_at: 73.hours.from_now,
                                         available_type: 'machines', machines: [Machine.find(2)])
    assert_refused(build_slot(72.hours.from_now).id)
  end

  test 'member cannot move to a missing slot' do
    assert_refused(0)
  end

  test 'member cannot move to a locked availability' do
    target = build_slot(72.hours.from_now)
    @availability.update!(lock: true)
    assert_refused(target.id)
  end

  test 'member cannot move a canceled booking' do
    @booking.update!(canceled_at: Time.current)
    assert_refused(build_slot(72.hours.from_now).id)
  end

  test 'member can move to a free future slot and both caches are updated' do
    target = build_slot(72.hours.from_now)
    move_to(target.id)
    assert_response :ok
    assert_equal target.id, @booking.reload.slot_id
    assert_equal 0, @original.reload.reserved_places(@machine)
    assert_not_includes @original.reserved_users([@machine]), @member.id
    assert_equal 1, target.reload.reserved_places(@machine)
    assert_includes target.reserved_users([@machine]), @member.id
  end

  test 'moving to the same full slot is a no-op' do
    move_to(@original.id)
    assert_response :ok
    assert_equal 1, @original.reload.reserved_places(@machine)
  end

  test 'disabled moves remain forbidden by policy' do
    travel 1.second
    Setting.set('booking_move_enable', false)
    move_to(build_slot(72.hours.from_now).id)
    assert_response :forbidden
  end

  test 'admin can still move to a free past slot' do
    login_as(users(:user1), scope: :user)
    target = build_slot(1.hour.ago)
    move_to(target.id)
    assert_response :ok
    assert_equal target.id, @booking.reload.slot_id
  end

  private

  def build_slot(start_at)
    slot = Slot.create!(availability: @availability, start_at: start_at, end_at: start_at + 1.hour)
    Slots::PlacesCacheService.refresh(slot)
    slot.reload
  end

  def move_to(slot_id)
    put "/api/slots_reservations/#{@booking.id}", params: { slots_reservation: { slot_id: slot_id } }, as: :json
  end

  def assert_refused(slot_id)
    move_to(slot_id)
    assert_response :unprocessable_entity
    assert JSON.parse(response.body).key?('slot_id')
    assert_equal @original.id, @booking.reload.slot_id
  end
end
