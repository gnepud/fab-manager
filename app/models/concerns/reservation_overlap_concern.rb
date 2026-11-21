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

    existing = existing_overlap_candidates(types)
    pending = pending_overlap_candidates(all_items, types)

    cart_item_reservation_slots.any? do |sr|
      slot = sr.slot
      existing.where('slots.start_at < ? AND slots.end_at > ?', slot.end_at, slot.start_at)
              .includes(:reservation).any? { |other| other.reservation.reservable_type != 'Event' || other.is_valid != false } ||
        pending.any? { |other| !other.equal?(sr) && other.slot && slots_overlap?(slot, other.slot) }
    end
  end

  def pending_overlap_candidates(all_items, types)
    all_items.select { |item| item.is_a?(CartItem::Reservation) && types.include?(item.reservable_type) }
             .reject { |item| same_event?(item) }
             .flat_map(&:cart_item_reservation_slots)
  end

  def existing_overlap_candidates(types)
    existing = SlotsReservation.joins(:reservation, :slot)
                               .where(reservations: { statistic_profile_id: customer.statistic_profile.id, reservable_type: types },
                                      canceled_at: nil)
    return existing unless reservable_type == 'Event'

    existing.where.not(reservations: { reservable_type: 'Event', reservable_id: reservable_id })
  end

  def same_event?(item)
    reservable_type == 'Event' && item.reservable_type == 'Event' && reservable_id == item.reservable_id
  end

  def slots_overlap?(slot, other)
    slot.start_at < other.end_at && slot.end_at > other.start_at
  end
end
