# frozen_string_literal: true

# Overlap validation for reservations in a shopping cart.
module ReservationOverlapConcern
  protected

  def overlapping_reservations?(all_items)
    return false if operator.privileged? || Setting.get('book_overlapping_slots')

    categories = Setting.get('overlapping_categories').to_s.split(',')
    types = {
      'training_reservations' => 'Training',
      'machine_reservations' => 'Machine',
      'space_reservations' => 'Space',
      'events_reservations' => 'Event'
    }.values_at(*categories).compact
    return false if types.empty?

    existing = SlotsReservation.joins(:reservation, :slot)
                               .where(reservations: { statistic_profile_id: customer.statistic_profile.id, reservable_type: types },
                                      canceled_at: nil)
    pending = all_items.select { |item| item.is_a?(CartItem::Reservation) && types.include?(item.reservable_type) }
                       .flat_map(&:cart_item_reservation_slots)

    cart_item_reservation_slots.any? do |sr|
      slot = sr.slot
      existing.where('slots.start_at < ? AND slots.end_at > ?', slot.end_at, slot.start_at)
              .includes(:reservation).any? { |other| other.reservation.reservable_type != 'Event' || other.is_valid != false } ||
        pending.any? { |other| !other.equal?(sr) && other.slot && slots_overlap?(slot, other.slot) }
    end
  end

  def slots_overlap?(slot, other)
    slot.start_at < other.end_at && slot.end_at > other.start_at
  end
end
