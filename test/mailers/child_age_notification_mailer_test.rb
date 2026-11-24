# frozen_string_literal: true

require 'test_helper'

class ChildAgeNotificationMailerTest < ActionMailer::TestCase
  test 'the English child age email shows the eighteenth birthday' do
    assert_birthday_date(:en, eighteenth_birthday, Date.current)
  end

  test 'the French child age email shows the eighteenth birthday' do
    assert_birthday_date(:fr, eighteenth_birthday, Date.current)
  end

  test 'the child age email handles a leap day birthday' do
    assert_birthday_date(:en, leap_day_birthday, leap_day_birthday.advance(years: 18))
  end

  private

  def eighteenth_birthday
    Date.current.advance(years: -18)
  end

  def leap_day_birthday
    year = (Date.current.year - 1).downto(Date.current.year - 17).find { |candidate| Date.leap?(candidate) }
    Date.new(year, 2, 29)
  end

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
