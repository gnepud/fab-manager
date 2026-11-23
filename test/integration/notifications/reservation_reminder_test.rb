# frozen_string_literal: true

require 'test_helper'

class ReservationReminderNotificationTest < ActionDispatch::IntegrationTest
  setup do
    @reservation = reservations(:reservation_2)
    @canceled_slot = slots(:slot_2)
    @active_slot = Slot.create!(availability: @canceled_slot.availability,
                                start_at: @canceled_slot.end_at,
                                end_at: @canceled_slot.end_at + 1.hour)
    @reservation.slots_reservations.create!(slot: @active_slot)
    @canceled_slot_reservation = @reservation.slots_reservations.find_by(slot: @canceled_slot)
    @canceled_slot_reservation.update!(canceled_at: Time.current)

    @notification = Notification.create!(
      notification_type: NotificationType.find_by(name: 'notify_member_reservation_reminder'),
      receiver: @reservation.user,
      attached_object: @reservation
    )
    login_as(@reservation.user, scope: :user)
  end

  test 'in-app reminder headlines the next slot that was not canceled' do
    description = reminder_description

    assert_includes description, I18n.l(@active_slot.start_at, format: :long)
    assert_not_includes description, I18n.l(@canceled_slot.start_at, format: :long)
  end

  test 'in-app reminder still renders when every slot was canceled' do
    @reservation.slots_reservations.where(canceled_at: nil).find_each { |sr| sr.update!(canceled_at: Time.current) }

    assert_includes reminder_description, I18n.l(@canceled_slot.start_at, format: :long)
  end

  private

  def reminder_description
    get '/api/notifications'

    assert_equal 200, response.status, response.body
    json_response(response.body)[:notifications].find { |n| n[:id] == @notification.id }[:message][:description]
  end
end
