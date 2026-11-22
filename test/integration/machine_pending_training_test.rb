# frozen_string_literal: true

require 'test_helper'

class MachinePendingTrainingTest < ActionDispatch::IntegrationTest
  setup do
    @member = User.find(3)
    @machine = Machine.find(1)
    @reservation = Reservation.find(1)
    @training = @reservation.reservable
    @machine.trainings = [@training]
    @member.statistic_profile.trainings = []
    @slot_reservation = @reservation.slots_reservations.first
    @slot = @slot_reservation.slot
    @slot.availability.update!(lock: false)
    @slot.update!(start_at: 1.day.from_now, end_at: 1.day.from_now + 1.hour)
    @reservation.update!(statistic_profile: @member.statistic_profile)
    login_as(@member, scope: :user)
  end

  test 'no pending training without a future reservation' do
    @slot.update!(start_at: 1.day.ago, end_at: 1.day.ago + 1.hour)

    assert_no_pending_training
  end

  test 'a canceled future training is not pending' do
    @slot_reservation.update!(canceled_at: Time.current)

    assert_no_pending_training
  end

  test 'a locked future training is not pending' do
    @slot.availability.update!(lock: true)

    assert_no_pending_training
  end

  test 'an active future training is pending' do
    assert_equal @reservation, @member.next_training_reservation_by_machine(@machine)
    assert_pending_slot @slot
  end

  test 'a canceled first slot does not hide the active slot date' do
    @slot_reservation.update!(canceled_at: Time.current)
    active_slot = add_slot(2.days.from_now)

    assert_equal @reservation, @member.next_training_reservation_by_machine(@machine)
    assert_pending_slot active_slot
  end

  test 'a past first slot does not hide the active slot date' do
    @slot.update!(start_at: 1.day.ago, end_at: 1.day.ago + 1.hour)
    active_slot = add_slot(2.days.from_now)

    assert_pending_slot active_slot
  end

  test 'pending slots are ordered by date rather than insertion order' do
    active_slot = add_slot(12.hours.from_now)

    assert_pending_slot active_slot
  end

  private

  def add_slot(start_at)
    slot = Slot.create!(availability: @slot.availability, start_at: start_at, end_at: start_at + 1.hour,
                        places: [{ user_ids: [], reservable_id: @training.id, reservable_type: 'Training', reserved_places: 0 }])
    @reservation.slots_reservations.create!(slot: slot)
    slot
  end

  def machine_response
    get "/api/machines/#{@machine.id}", headers: default_headers
    assert_response :success
    json_response(response.body)
  end

  def assert_no_pending_training
    assert_nil @member.next_training_reservation_by_machine(@machine)
    assert_nil machine_response[:current_user_next_training_reservation]
  end

  def assert_pending_slot(slot)
    result = machine_response
    assert_not result[:current_user_is_trained]
    pending = result.fetch(:current_user_next_training_reservation)
    assert_equal @reservation.id, pending[:id]
    first_slot = pending.fetch(:slots_reservations_attributes).first
    assert_nil first_slot[:canceled_at]
    assert_equal slot.id, first_slot[:slot_id]
    assert_equal slot.start_at.iso8601, first_slot.dig(:slot_attributes, :start_at)
  end
end
