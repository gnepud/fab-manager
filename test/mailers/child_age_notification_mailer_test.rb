# frozen_string_literal: true

require 'test_helper'

class ChildAgeNotificationMailerTest < ActionMailer::TestCase
  test 'the English child age email shows the eighteenth birthday' do
    assert_birthday_date(:en, Date.new(2008, 11, 24), Date.new(2026, 11, 24))
  end

  test 'the French child age email shows the eighteenth birthday' do
    assert_birthday_date(:fr, Date.new(2008, 11, 24), Date.new(2026, 11, 24))
  end

  test 'the child age email handles a leap day birthday' do
    assert_birthday_date(:en, Date.new(2012, 2, 29), Date.new(2030, 2, 28))
  end

  private

  def assert_birthday_date(locale, birthday, expected_date)
    parent = users(:user2)
    child = Child.create!(user: parent, first_name: 'Arthur', last_name: 'Pendelton', birthday: birthday)
    type = NotificationType.find_or_create_by!(name: 'notify_user_when_child_age_will_be_18') do |notification_type|
      notification_type.category = 'users_accounts'
      notification_type.is_configurable = false
    end
    notification = Notification.create!(notification_type: type, receiver: parent, attached_object: child)

    I18n.with_locale(locale) do
      email = NotificationsMailer.send_mail_by(notification).message

      assert_equal [parent.email], email.to
      assert_includes email.body.decoded, I18n.l(expected_date, format: :default)
      assert_not_includes email.body.decoded, I18n.l(birthday, format: :default)
    end
  end
end
