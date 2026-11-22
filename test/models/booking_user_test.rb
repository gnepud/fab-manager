# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('db/migrate/20261122230000_anonymize_orphaned_child_bookings')

class BookingUserTest < ActiveSupport::TestCase
  test 'anonymized names use the current locale without storing a translated label' do
    booking = BookingUser.create!(name: nil)

    { fr: 'Utilisateur supprimé', en: 'Deleted user' }.each do |locale, label|
      I18n.with_locale(locale) { assert_equal label, booking.name }
    end
    assert_nil booking.reload[:name]
  end

  test 'named guest bookings retain their names' do
    booking = BookingUser.create!(name: 'Invited Guest')

    assert_equal 'Invited Guest', booking.name
  end

  test 'migration anonymizes only orphaned child bookings and is idempotent' do
    child = users(:user2).children.create!(first_name: 'Live', last_name: 'Child', birthday: 8.years.ago)
    live_booking = BookingUser.create!(booked: child, name: child.full_name)
    user_booking = BookingUser.create!(booked: users(:user2), name: 'Adult')
    guest_booking = BookingUser.create!(name: 'Invited Guest')
    orphan = BookingUser.create!(booked_type: 'Child', booked_id: child.id + 1, name: 'Deleted Child')
    missing_id = BookingUser.create!(booked_type: 'Child', booked_id: nil, name: 'Deleted Child Without ID')
    unchanged = [live_booking, user_booking, guest_booking].map(&:attributes)
    orphan_attributes = orphan.attributes.except('name', 'booked_type', 'booked_id')

    2.times do
      assert_no_difference('BookingUser.count') { AnonymizeOrphanedChildBookings.new.up }

      [orphan, missing_id].each do |booking|
        booking.reload
        assert_nil booking[:name]
        assert_nil booking.booked_type
        assert_nil booking.booked_id
      end
      assert_equal orphan_attributes, orphan.attributes.except('name', 'booked_type', 'booked_id')
      assert_equal unchanged, [live_booking, user_booking, guest_booking].map(&:reload).map(&:attributes)
    end
  end
end
