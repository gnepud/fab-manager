# frozen_string_literal: true

require 'test_helper'

class NotifyMemberReservationReminderTest < ActionMailer::TestCase
  setup do
    @reservation = reservations(:reservation_2)
    @canceled_slot = slots(:slot_2)
    @active_slot = Slot.create!(availability: @canceled_slot.availability,
                                start_at: @canceled_slot.end_at,
                                end_at: @canceled_slot.end_at + 1.hour)
    @reservation.slots_reservations.create!(slot: @active_slot)
    @reservation.slots_reservations.find_by(slot: @canceled_slot).update!(canceled_at: Time.current)

    @notification = Notification.create!(
      notification_type: NotificationType.find_by(name: 'notify_member_reservation_reminder'),
      receiver: @reservation.user,
      attached_object: @reservation
    )
  end

  test 'reminder only mentions the slots that were not canceled' do
    mail = NotificationsMailer.send_mail_by(@notification).deliver_now
    body = mail.body.to_s

    headline = Nokogiri::HTML(body).at('em').text
    assert_equal I18n.l(@active_slot.start_at, format: :long), headline

    assert_includes body, "#{I18n.l @active_slot.start_at, format: :long} - #{I18n.l @active_slot.end_at, format: :hour_minute}"
    assert_not_includes body, I18n.l(@canceled_slot.start_at, format: :long)
  end
end
