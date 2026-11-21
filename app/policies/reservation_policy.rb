# frozen_string_literal: true

# Check the access policies for API::ReservationsController
class ReservationPolicy < ApplicationPolicy
  def create?
    user.admin? || (user.manager? && record.user_id != user.id) || record.price.zero?
  end

  def show?
    return false unless user
    return true if user.admin? || user.manager?

    profile_id = user.statistic_profile&.id
    profile_id.present? && record.statistic_profile_id == profile_id
  end

  def update?
    user.admin? || user.manager? || record.user == user
  end

  def confirm_payment?
    user.admin? || user.manager?
  end

  def update_attributes?(attributes)
    return true if privileged_user?
    return false unless record.user == user

    target = target_reservable(attributes)
    return false unless target && valid_slot_attributes?(attributes)
    return false if reservable_changed?(target) && !event_move_allowed?(target)

    slots_update_allowed?(attributes, target)
  end

  private

  def privileged_user?
    user.admin? || user.manager?
  end

  def target_reservable(attributes)
    return record.reservable unless attributes.key?(:reservable_id)

    record.reservable.class.find_by(id: attributes[:reservable_id])
  end

  def event_move_allowed?(target)
    record.reservable_type == 'Event' && record.reservable.recurrence_id.present? &&
      target.recurrence_id == record.reservable.recurrence_id &&
      (target.nb_free_places.nil? || target.nb_free_places >= record.total_booked_seats)
  end

  def valid_slot_attributes?(attributes)
    slot_ids = record.slots_reservations.ids
    requested_ids = slot_attributes(attributes).map { |attrs| attrs[:id].to_i }
    requested_ids.uniq == requested_ids && requested_ids.all? { |id| slot_ids.include?(id) }
  end

  def slot_attributes(attributes)
    values = attributes.fetch(:slots_reservations_attributes, [])
    values.respond_to?(:values) ? values.values : values
  end

  def reservable_changed?(target)
    target != record.reservable
  end

  def slots_update_allowed?(attributes, target)
    changed = reservable_changed?(target)
    record.slots_reservations.all? do |slot_reservation|
      slot_attrs = slot_attributes(attributes).find { |item| item[:id].to_i == slot_reservation.id }
      slot = slot_for(slot_attrs, slot_reservation)
      next true unless changed || slot != slot_reservation.slot

      movable?(slot_reservation) && slot_belongs_to?(slot, target)
    end
  end

  def slot_for(attributes, slot_reservation)
    attributes&.key?(:slot_id) ? Slot.find_by(id: attributes[:slot_id]) : slot_reservation.slot
  end

  def movable?(slot_reservation)
    slot_reservation.canceled_at.nil? && Setting.get('booking_move_enable') == true &&
      slot_reservation.slot.start_at >= Time.current + Setting.get('booking_move_delay').to_i.hours
  end

  def slot_belongs_to?(slot, target)
    return false unless slot
    return slot.availability_id == target.availability_id if record.reservable_type == 'Event'

    target.availabilities.exists?(id: slot.availability_id)
  end
end
