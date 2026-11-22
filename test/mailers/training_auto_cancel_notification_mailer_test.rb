# frozen_string_literal: true

require 'test_helper'

class TrainingAutoCancelNotificationMailerTest < ActionMailer::TestCase
  %i[en fr].each do |locale|
    [true, false].each do |auto_refund|
      test "member auto-cancel email in #{locale} with auto_refund #{auto_refund} uses the reserved slot dates" do
        slot_reservation = slots_reservations(:one)
        notification = create_notification('notify_member_training_auto_cancelled', slot_reservation,
                                           slot_reservation.reservation.user, auto_refund)

        I18n.with_locale(locale) do
          email = deliver_notification(notification)

          assert_equal [slot_reservation.reservation.user.email], email.to
          assert_schedule(email, slot_reservation.slot, slot_reservation.reservation.reservable)
          refund_text = I18n.t('notifications_mailer.notify_member_training_auto_cancelled.body.auto_refund')
          auto_refund ? assert_includes(email.body.decoded, refund_text) : assert_not_includes(email.body.decoded, refund_text)
        end
      end
    end

    test "admin auto-cancel email in #{locale} uses the availability dates" do
      availability = slots_reservations(:one).slot.availability
      admin = users(:user1)
      notification = create_notification('notify_admin_training_auto_cancelled', availability, admin, false)

      I18n.with_locale(locale) do
        email = deliver_notification(notification)

        assert_equal [admin.email], email.to
        assert_schedule(email, availability, availability.trainings.first)
        assert_includes email.body.decoded, I18n.t('notifications_mailer.notify_admin_training_auto_cancelled.body.manual_refund')
      end
    end
  end

  private

  def create_notification(type, attached_object, receiver, auto_refund)
    Notification.create!(notification_type: NotificationType.find_by!(name: type), receiver: receiver,
                         attached_object: attached_object, meta_data: { auto_refund: auto_refund })
  end

  def deliver_notification(notification)
    email = nil
    assert_emails 1 do
      email = NotificationsMailer.send_mail_by(notification).deliver_now
    end
    email
  end

  def assert_schedule(email, schedule, training)
    assert_includes email.body.decoded, training.name
    assert_includes email.body.decoded, I18n.l(schedule.start_at.to_date)
    assert_includes email.body.decoded, I18n.l(schedule.start_at, format: :hour_minute)
    assert_includes email.body.decoded, I18n.l(schedule.end_at, format: :hour_minute)
  end
end
