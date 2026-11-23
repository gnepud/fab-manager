# frozen_string_literal: true

reservation = notification.attached_object
slot = reservation.active_slots.first || reservation.slots.order(:start_at).first

json.title notification.notification_type
json.description t('.reminder_you_have_a_reservation_RESERVABLE_to_be_held_on_DATE_html',
                   RESERVABLE: reservation.reservable.name,
                   DATE: I18n.l(slot.start_at, format: :long))
