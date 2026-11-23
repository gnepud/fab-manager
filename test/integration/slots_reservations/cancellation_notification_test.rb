# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class CancellationNotificationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:user1)
    @member = users(:user2)
    start_at = 5.days.from_now.change(hour: 12)
    availability = Availability.create!(available_type: 'space', start_at: start_at, end_at: start_at + 1.hour,
                                        spaces: [Space.find(1)])
    slot = availability.slots.create!(start_at: start_at, end_at: start_at + 1.hour)
    reservation = Reservation.create!(reservable: Space.find(1), statistic_profile: @member.statistic_profile,
                                      slots_reservations_attributes: [{ slot_id: slot.id }])
    @slot_reservation = reservation.slots_reservations.first
  end

  test 'admin cancellation email identifies the actor rather than blaming the member' do
    cancel_as(@admin)
    notification = cancellation_notification(@admin)
    assert_includes email_text(notification), "#{@admin.profile.full_name} cancelled #{@member.profile.full_name}'s reservation"
    assert_not_includes email_text(notification), "User #{@member.profile.full_name} has cancelled"
    assert_equal @admin.id, notification.get_meta_data(:canceled_by_id)
    assert_equal @admin.profile.full_name, cancellation_notification(@member).get_meta_data(:canceled_by_name)
    assert_passive_notifications
  end

  test 'member cancellation retains the existing self cancellation wording' do
    Setting.set('booking_cancel_enable', true)
    Setting.set('booking_cancel_delay', 0)
    cancel_as(@member)
    assert_includes email_text(cancellation_notification(@admin)), "User #{@member.profile.full_name} has cancelled his reservation"
    assert_equal @member.id, cancellation_notification(@admin).get_meta_data(:canceled_by_id)
    assert_passive_notifications
  end

  test 'cancellation without an actor does not invent a member actor' do
    SlotsReservationsService.cancel(@slot_reservation)
    assert_includes email_text(cancellation_notification(@admin)), "The reservation of #{@member.profile.full_name} was cancelled"
    assert_not_includes email_text(cancellation_notification(@admin)), "User #{@member.profile.full_name} has cancelled"
  end

  test 'legacy notifications without metadata use neutral wording' do
    notification = Notification.create!(notification_type: NotificationType.find_by!(name: 'notify_admin_slot_is_canceled'),
                                        receiver: @admin, attached_object: @slot_reservation)
    assert_includes email_text(notification), "The reservation of #{@member.profile.full_name} was cancelled"
  end

  test 'cancellation actor wording is present in every application locale' do
    %w[en fr de es es-MX it no pt sv zh-CN zu].each do |locale|
      %w[reservation_cancelled_by reservation_cancelled].each do |key|
        scope = 'notifications_mailer.notify_admin_slot_is_canceled.body'
        text = I18n.t("#{scope}.#{key}", locale: locale, fallback: false, raise: true, NAME: 'Member', ACTOR: 'Operator')
        assert_includes text, 'Member'
        assert_includes text, 'Operator' if key == 'reservation_cancelled_by'
      end
    end
  end

  private

  def cancel_as(user)
    login_as(user, scope: :user)
    put "/api/slots_reservations/#{@slot_reservation.id}/cancel"
    assert_response :ok
  end

  def cancellation_notification(receiver)
    Notification.where(attached_object: @slot_reservation, receiver: receiver).order(:id).last.reload
  end

  def email_text(notification)
    email = CustomAsset.stub(:get_url, '/logo.png') { NotificationsMailer.send_mail_by(notification).message }
    Nokogiri::HTML(email.body.decoded).text.squish
  end

  def assert_passive_notifications
    member_email = email_text(cancellation_notification(@member))
    assert_includes member_email, 'has been canceled'
    [@member, @admin].each do |user|
      login_as(user, scope: :user)
      get '/api/notifications'
      assert_response :ok
      notification = json_response(response.body)[:notifications].find { |item| item[:id] == cancellation_notification(user).id }
      assert_includes notification[:message][:description], 'cancelled'
    end
  end
end
