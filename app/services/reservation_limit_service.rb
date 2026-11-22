# frozen_string_literal: true

# Check if a user if allowed to book a reservation without exceeding the limits set by his plan
class ReservationLimitService
  class << self
    # @param plan [Plan,NilClass]
    # @param customer [User]
    # @param reservation [CartItem::Reservation]
    # @param cart_items [Array<CartItem::BaseItem>]
    # @return [Boolean]
    def authorized?(plan, customer, reservation, cart_items)
      return true if plan.nil? || !plan.limiting

      return true if reservation.nil? || !reservation.is_a?(CartItem::Reservation)

      limit = limit(plan, reservation.reservable)
      return true if limit.nil?

      reservation.cart_item_reservation_slots.group_by { |sr| sr.slot.start_at.to_date }.each_pair do |date, reservation_slots|
        daily_duration = reservations_duration(customer, date, reservation, cart_items) +
                         (reservation_slots.map { |sr| sr.slot.duration }.reduce(:+) || 0)
        return false if Rational(daily_duration / 3600).to_f > limit.limit
      end

      true
    end

    # @param reservation [Reservation]
    # @return [Date,NilClass]
    def reached_limit_date(reservation)
      user = reservation.user
      plan = user.subscribed_plan
      return nil if plan.nil? || !plan.limiting

      limit = limit(plan, reservation.reservable)
      return nil if limit.nil?

      reservation.slots_reservations.group_by { |sr| sr.slot.start_at.to_date }.each_pair do |date, reservation_slots|
        daily_duration = saved_reservations_durations(user, reservation.reservable, date, reservation) +
                         (reservation_slots.map { |sr| sr.slot.duration }.reduce(:+) || 0)
        return date if Rational(daily_duration / 3600).to_f >= limit.limit
      end

      nil
    end

    # @param plan [Plan,NilClass]
    # @param reservable [Machine,Event,Space,Training]
    # @return [PlanLimitation] in hours
    def limit(plan, reservable)
      return nil unless plan&.limiting

      limitations = plan&.plan_limitations&.filter { |limit| limit.reservables.include?(reservable) }
      limitations&.find { |limit| limit.limitable_type != 'MachineCategory' } || limitations&.first
    end

    private

    # @param customer [User]
    # @param date [Date]
    # @param reservation [CartItem::Reservation]
    # @param cart_items [Array<CartItem::BaseItem>]
    # @return [Integer] in seconds
    def reservations_duration(customer, date, reservation, cart_items)
      cart_duration = cart_items.sum do |item|
        next 0 unless item.is_a?(CartItem::Reservation) && item != reservation && item.reservable == reservation.reservable

        item.cart_item_reservation_slots.select { |sr| sr.slot.start_at.to_date == date }.sum { |sr| sr.slot.duration }
      end

      saved_reservations_durations(customer, reservation.reservable, date) + cart_duration
    end

    # @param customer [User]
    # @param reservable [Machine,Event,Space,Training]
    # @param date [Date]
    # @param reservation [Reservation]
    # @return [Integer] in seconds
    def saved_reservations_durations(customer, reservable, date, reservation = nil)
      reservations = customer.reservations.where(reservable: reservable)
      reservations = reservations.where.not(id: reservation.id) unless reservation.nil?
      local_day = date.in_time_zone...date.next_day.in_time_zone

      Slot.joins(:slots_reservations)
          .where(slots_reservations: { reservation_id: reservations.select(:id), canceled_at: nil }, start_at: local_day)
          .sum(&:duration)
    end
  end
end
