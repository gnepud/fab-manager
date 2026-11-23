# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class NotificationDeliveryStateTest < ActionMailer::TestCase
  setup do
    @slot_reservation = slots_reservations(:one)
    @notification = Notification.create!(
      notification_type: NotificationType.find_by!(name: 'notify_member_training_auto_cancelled'),
      receiver: @slot_reservation.reservation.user, attached_object: @slot_reservation
    )
    @errors = []
  end

  test 'template failure is logged without marking the notification sent or raising' do
    assert_emails 0 do
      capture_errors do
        @slot_reservation.stub(:slot, ->(*) { raise 'forced template failure' }) do
          NotificationsMailer.send_mail_by(@notification).deliver_now
        end
      end
    end

    assert_not @notification.reload.is_send
    assert_error_logged('forced template failure')
  end

  test 'successful delivery marks the notification sent' do
    assert_emails 1 do
      NotificationsMailer.send_mail_by(@notification).deliver_now
    end

    assert @notification.reload.is_send
  end

  test 'rendering a preview does not mark the notification sent' do
    assert_emails 0 do
      NotificationsMailer.send_mail_by(@notification).message
    end

    assert_not @notification.reload.is_send
  end

  [true, false].each do |raise_errors|
    test "delivery failure is logged and not marked sent with raise_delivery_errors #{raise_errors}" do
      delivery = NotificationsMailer.send_mail_by(@notification)
      message = delivery.message
      message.raise_delivery_errors = raise_errors

      assert_emails 0 do
        capture_errors do
          message.delivery_method.stub(:deliver!, ->(*) { raise IOError, 'forced delivery failure' }) do
            assert_nothing_raised { delivery.deliver_now }
          end
        end
      end

      assert_not @notification.reload.is_send
      assert_error_logged('forced delivery failure')
    end
  end

  test 'disabled deliveries do not mark the notification sent' do
    delivery = NotificationsMailer.send_mail_by(@notification)
    delivery.message.perform_deliveries = false

    assert_emails(0) { delivery.deliver_now }

    assert_not @notification.reload.is_send
  end

  test 'a failed notification can be successfully retried' do
    capture_errors do
      @slot_reservation.stub(:slot, ->(*) { raise 'forced template failure' }) do
        NotificationsMailer.send_mail_by(@notification).deliver_now
      end
    end
    assert_not @notification.reload.is_send

    assert_emails(1) { @notification.deliver_now }

    assert @notification.reload.is_send
  end

  private

  def capture_errors(&)
    Rails.logger.stub(:error, ->(message) { @errors << message }, &)
  end

  def assert_error_logged(message)
    assert(@errors.any? { |error| error.include?('[NotificationsMailer] notification cannot be sent:') && error.include?(message) })
  end
end
