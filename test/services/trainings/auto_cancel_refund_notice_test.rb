# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class Trainings::AutoCancelRefundNoticeTest < ActionMailer::TestCase
  setup do
    Setting.set('wallet_module', true)
    @training = Training.find(4)
    @training.update!(auto_cancel: true, auto_cancel_threshold: 3, auto_cancel_deadline: 24)
    @slot = Availability.find(22).slots.first
  end

  %i[en fr].each do |locale|
    test "subscription credits do not promise a wallet refund in #{locale}" do
      book_training(3)
      assert_equal 0, @invoice.total

      assert_refund_notice(false, locale)
    end

    test "a fully discounted slot does not promise a wallet refund in #{locale}" do
      book_training(4, coupon: true)
      assert_equal 0, @invoice.total
      assert_equal 2500, @invoice.invoice_items.sole.amount

      assert_refund_notice(false, locale)
    end

    test "a paid slot promises its actual wallet refund in #{locale}" do
      book_training(4)
      assert_equal 2500, @invoice.total

      assert_refund_notice(true, locale)
    end
  end

  test 'an unsuccessful wallet credit does not promise a refund' do
    book_training(4)
    service = WalletService.new(user: @customer, wallet: @customer.wallet)

    service.stub(:credit, nil) do
      WalletService.stub(:new, service) { assert_refund_notice(false, :en) }
    end
  end

  test 'the admin sees refunds when a paid booking is followed by a free booking' do
    book_training(4)
    book_training(3)

    assert_difference('WalletTransaction.count', 1) do
      assert_difference('Avoir.count', 1) { Trainings::AutoCancelService.auto_cancel_reservations(@training) }
    end

    notification = admin_notification
    assert notification.get_meta_data(:auto_refund)
    I18n.with_locale(:en) { assert_admin_notice(notification, true) }
  end

  test 'the admin retains manual refund instructions when the wallet module is disabled' do
    book_training(4)
    Setting.set('wallet_module', false)

    assert_refund_notice(false, :en, manual_refund: true)
  end

  test 'an empty cancelled availability does not promise refunds' do
    assert_no_difference(['WalletTransaction.count', 'Avoir.count']) do
      Trainings::AutoCancelService.auto_cancel_reservations(@training)
    end

    notification = admin_notification
    assert_not notification.get_meta_data(:auto_refund)
    I18n.with_locale(:en) { assert_admin_notice(notification, false) }
  end

  private

  def book_training(customer_id, coupon: false)
    @customer = User.find(customer_id)
    @training.amount_by_group(@customer.group_id).update!(amount: 2500)
    params = {
      customer_id: @customer.id,
      items: [{ reservation: { reservable_id: @training.id, reservable_type: 'Training',
                               slots_reservations_attributes: [{ slot_id: @slot.id }] } }]
    }
    params[:coupon_code] = coupons(:cash2).tap { |record| record.update!(amount_off: 2500) }.code if coupon
    CartService.new(User.admins.first).from_hash(ActionController::Parameters.new(params)).build_and_save(nil, nil)
    @reservation = Reservation.order(:id).last
    @slot_reservation = @reservation.slots_reservations.sole
    @invoice = @reservation.invoice_items.sole.invoice
    assert_not @slot_reservation.offered?
  end

  def assert_refund_notice(refunded, locale, manual_refund: false)
    transactions_before = WalletTransaction.count
    credits_before = Avoir.count

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    assert @slot_reservation.reload.canceled_at
    assert_equal transactions_before + (refunded ? 1 : 0), WalletTransaction.count
    assert_equal credits_before + (refunded ? 1 : 0), Avoir.count
    notification = Notification.find_by!(attached_object: @slot_reservation,
                                         notification_type_id: NotificationType.find_by!(name: 'notify_member_training_auto_cancelled').id)
    assert_equal refunded, notification.get_meta_data(:auto_refund)
    admin = admin_notification
    assert_equal refunded, admin.get_meta_data(:auto_refund)

    I18n.with_locale(locale) do
      email = nil
      assert_emails(1) { email = NotificationsMailer.send_mail_by(notification).deliver_now }
      description = JSON.parse(ApplicationController.render(
                                 partial: 'api/notifications/notify_member_training_auto_cancelled',
                                 formats: [:json], locals: { notification: notification }
                               )).fetch('description')
      mail_text = I18n.t('notifications_mailer.notify_member_training_auto_cancelled.body.auto_refund')
      notice_text = I18n.t('api.notifications.notify_member_training_auto_cancelled.auto_refund')
      if refunded
        assert_includes email.body.decoded, mail_text
        assert_includes description, notice_text
      else
        assert_not_includes email.body.decoded, mail_text
        assert_not_includes description, notice_text
      end
      assert_admin_notice(admin, refunded, manual_refund: manual_refund)
    end
  end

  def admin_notification
    Notification.find_by!(attached_object: @slot.availability, receiver: User.admins.first,
                          notification_type_id: NotificationType.find_by!(name: 'notify_admin_training_auto_cancelled').id)
  end

  def assert_admin_notice(notification, refunded, manual_refund: false)
    email = nil
    assert_emails(1) { email = NotificationsMailer.send_mail_by(notification).deliver_now }
    description = JSON.parse(ApplicationController.render(
                               partial: 'api/notifications/notify_admin_training_auto_cancelled',
                               formats: [:json], locals: { notification: notification }
                             )).fetch('description')
    mail_text = I18n.t('notifications_mailer.notify_admin_training_auto_cancelled.body.auto_refund')
    notice_text = I18n.t('api.notifications.notify_admin_training_auto_cancelled.auto_refund')
    if refunded
      assert_includes email.body.decoded, mail_text
      assert_includes description, notice_text
    else
      assert_not_includes email.body.decoded, mail_text
      assert_not_includes description, notice_text
    end
    manual_mail_text = I18n.t('notifications_mailer.notify_admin_training_auto_cancelled.body.manual_refund')
    manual_notice_text = I18n.t('api.notifications.notify_admin_training_auto_cancelled.manual_refund')
    assert_equal manual_refund, email.body.decoded.include?(manual_mail_text)
    assert_equal manual_refund, description.include?(manual_notice_text)
  end
end
