# frozen_string_literal: true

# Services for individual slot reservations.
module SlotsReservations; end

# Validate the destination before moving a reservation and its cached places.
class SlotsReservations::MoveService
  def initialize(slots_reservation, user)
    @slots_reservation = slots_reservation
    @user = user
  end

  def move(slot_id)
    target = Slot.find_by(id: slot_id)
    return invalid('does not exist') unless target

    @slots_reservation.with_lock do
      next invalid('reservation is canceled') if @slots_reservation.canceled_at.present?
      next true if @slots_reservation.slot_id == target.id

      target.with_lock do
        next false unless valid_target?(target)

        @slots_reservation.update(slot: target)
      end
    end
  end

  private

  def valid_target?(target)
    reservable = @slots_reservation.reservation.reservable
    availability = target.availability
    types = { 'Machine' => 'machines', 'Space' => 'space', 'Training' => 'training', 'Event' => 'event' }
    unless availability.available_type == types[reservable.class.name] && availability.available_ids.include?(reservable.id)
      return invalid('is not available for this reservable')
    end
    return invalid('is locked') if availability.lock
    return invalid('is full') if target.full?(reservable)
    return true if @user.privileged?

    now = Time.current
    delay = Setting.get('booking_move_delay').to_i.hours
    return invalid('is outside the allowed move period') unless Setting.get('booking_move_enable') == true &&
                                                                target.start_at > now && target.start_at >= now + delay

    true
  end

  def invalid(message)
    @slots_reservation.errors.add(:slot_id, message)
    false
  end
end
