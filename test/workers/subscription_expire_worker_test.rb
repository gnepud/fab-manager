# frozen_string_literal: true

require 'test_helper'

class SubscriptionExpireWorkerTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 11, 15, 12)
    @subscription = subscriptions('subscription_2')
    @subscription.offer_days.destroy_all
  end

  [0, 7].each do |delay|
    test "notify once when a free extension ends in #{delay} days" do
      @subscription.update!(expiration_date: 10.days.ago)
      @subscription.offer_days.create!(start_at: 10.days.ago, end_at: delay.days.from_now)
      @subscription.offer_days.create!(start_at: 5.days.ago, end_at: (delay + 1).days.ago)

      assert_expiry_notifications(@subscription, delay, 1)
    end

    test "ignore the original expiration in #{delay} days when extended beyond it" do
      @subscription.update!(expiration_date: delay.days.from_now)
      @subscription.offer_days.create!(start_at: delay.days.from_now, end_at: (delay + 10).days.from_now)

      assert_expiry_notifications(@subscription, delay, 0)
    end

    test "notify once for a regular subscription ending in #{delay} days" do
      @subscription.update!(expiration_date: delay.days.from_now)

      assert_expiry_notifications(@subscription, delay, 1)
    end
  end

  test 'do not notify for an extension that has already ended' do
    @subscription.update!(expiration_date: 10.days.ago)
    @subscription.offer_days.create!(start_at: 10.days.ago, end_at: 1.day.ago)

    assert_expiry_notifications(@subscription, 0, 0)
  end

  private

  def assert_expiry_notifications(subscription, delay, count)
    suffix = delay.zero? ? 'is_expired' : 'will_expire_in_7_days'
    member = Notification.where(attached_object: subscription, receiver: subscription.user,
                                notification_type_id: NotificationType.find_by!(name: "notify_member_subscription_#{suffix}").id)
    admins = Notification.where(attached_object: subscription,
                                notification_type_id: NotificationType.find_by!(name: "notify_admin_subscription_#{suffix}").id)

    assert_difference -> { member.count }, count do
      assert_difference -> { admins.count }, count * User.admins_and_managers.count do
        SubscriptionExpireWorker.new.perform(delay)
      end
    end
  end
end
