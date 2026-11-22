# frozen_string_literal: true

require 'test_helper'

class ChildAgeWorkerTest < ActiveSupport::TestCase
  setup do
    @parent = users(:user2)
    @notification_type = NotificationType.find_or_create_by!(name: 'notify_user_when_child_age_will_be_18') do |type|
      type.category = 'users_accounts'
      type.is_configurable = false
    end
  end

  test 'notify the parent two days before the eighteenth birthday at a non-midnight time' do
    travel_to Time.zone.local(2026, 11, 22, 0, 0, 3.5), with_usec: true do
      child = create_child(Date.current.advance(years: -18, days: 2))
      other_child = create_child(Date.current.advance(years: -18, days: 3))

      assert_difference -> { notifications.count }, 1 do
        ChildAgeWorker.new.perform
      end

      notification = notifications.sole
      assert_equal @parent, notification.receiver
      assert_equal child, notification.attached_object
      assert_empty notifications.where(attached_object: other_child)
    end
  end

  test 'do not notify for another birthday' do
    travel_to Time.zone.local(2026, 11, 22, 0, 0, 3.5), with_usec: true do
      create_child(Date.current.advance(years: -18, days: 3))

      assert_no_difference -> { notifications.count } do
        ChildAgeWorker.new.perform
      end
    end
  end

  test 'do not notify when there are no children' do
    assert_no_difference -> { notifications.count } do
      ChildAgeWorker.new.perform
    end
  end

  private

  def create_child(birthday)
    Child.create!(user: @parent, first_name: 'Arthur', last_name: 'Pendelton', birthday: birthday)
  end

  def notifications
    Notification.where(notification_type: @notification_type)
  end
end
