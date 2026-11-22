# frozen_string_literal: true

require 'test_helper'

class SubscriptionExpireWorkerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @subscription = subscriptions('subscription_2')
    @subscription.offer_days.destroy_all
    @subscription.update!(expiration_date: 7.days.from_now, canceled_at: nil)
  end

  test 'renders the seven day reminder without legacy Stripe subscription attributes' do
    mailer = NotificationsMailer.new
    mailer.instance_variable_set(:@recipient, @subscription.user)
    mailer.instance_variable_set(:@attached_object, @subscription)

    body = mailer.render_to_string(template: 'notifications_mailer/notify_member_subscription_will_expire_in_7_days',
                                   layout: false)

    assert_includes body, @subscription.plan.human_readable_name
    assert_not_includes body, '#!/dashboard/profile'
  end

  test 'renders the same reminder for installment subscriptions without a legacy renewal link' do
    @subscription = subscriptions('subscription_6')
    assert_not_nil @subscription.original_payment_schedule
    notification_type = NotificationType.find_by!(name: 'notify_member_subscription_will_expire_in_7_days')
    notification = Notification.create!(receiver: @subscription.user, attached_object: @subscription,
                                        notification_type_id: notification_type.id)

    assert_emails 1 do
      NotificationsMailer.send_mail_by(notification).deliver_now
    end
    assert_not_includes ActionMailer::Base.deliveries.last.body.decoded, '#!/dashboard/profile'
  end

  test 'delivers the member seven day reminder for a subscription without a payment schedule' do
    assert_nil @subscription.original_payment_schedule

    SubscriptionExpireWorker.new.perform(7)

    notification = Notification.where(attached_object: @subscription, receiver: @subscription.user)
                               .joins(:notification_type)
                               .find_by!(notification_types: { name: 'notify_member_subscription_will_expire_in_7_days' })

    assert_emails 1 do
      NotificationsMailer.send_mail_by(notification).deliver_now
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [@subscription.user.email], mail.to
    assert_includes mail.body.decoded, @subscription.plan.human_readable_name
    assert_not_includes mail.body.decoded, '#!/dashboard/profile'
  end
end
