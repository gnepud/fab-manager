# frozen_string_literal: true

require 'test_helper'

class UserDeletionTest < ActiveSupport::TestCase
  setup do
    @user = users(:user2)
    @reservation = reservations('reservation_2')
    @slot = @reservation.slots.first
    @subscription = subscriptions('subscription_1')
    @reservation.update!(statistic_profile: @user.statistic_profile)
    @subscription.update!(statistic_profile: @user.statistic_profile)
  end

  %w[Machine Space Training Event].each do |type|
    test "future uncanceled #{type} slots block model destruction" do
      @slot.update!(start_at: 2.days.from_now, end_at: 2.days.from_now + 1.hour)
      @reservation.update_columns(reservable_type: type) # rubocop:disable Rails/SkipsModelValidations

      assert_not @user.destroy
      assert User.exists?(@user.id)
      assert_equal [I18n.t('members.deletion_blocked')], @user.errors.full_messages
      assert @user.profile.reload
    end
  end

  test 'canceled future slots do not block destruction' do
    @slot.update!(start_at: 2.days.from_now, end_at: 2.days.from_now + 1.hour)
    @reservation.slots_reservations.first.update!(canceled_at: Time.current)

    assert @user.destroy
  end

  test 'non-expired uncanceled subscriptions block even without a paid invoice' do
    @subscription.update!(canceled_at: nil)

    assert_not @user.destroy
    assert @subscription.reload
  end

  test 'expired subscriptions do not block destruction' do
    @subscription.update!(canceled_at: nil, expiration_date: 1.day.ago)

    assert @user.destroy
  end

  test 'offered days extending an otherwise expired subscription still block destruction' do
    @subscription.update!(canceled_at: nil, expiration_date: 1.day.ago)
    @subscription.offer_days.create!(start_at: 1.day.ago, end_at: 1.day.from_now)

    assert_not @user.destroy
  end

  test 'destroy bang raises and preserves the user when deletion is blocked' do
    @subscription.update!(canceled_at: nil)

    assert_raises(ActiveRecord::RecordNotDestroyed) { @user.destroy! }
    assert User.exists?(@user.id)
  end

  test 'a slot that has already started does not block destruction even if it ends in the future' do
    @slot.update!(start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert @user.destroy
  end

  test 'an active subscription paid by an unpaid schedule still blocks destruction' do
    subscription = subscriptions('subscription_6')
    subscription.update!(statistic_profile: @user.statistic_profile)
    schedule = subscription.original_payment_schedule
    original = schedule.attributes

    assert_not @user.destroy
    assert_equal original, schedule.reload.attributes
  end

  test 'the deletion error has a translation in every user-facing dictionary' do
    %w[de en es es-MX fr it no pt sv zh-CN zu].each do |locale|
      I18n.with_locale(locale) do
        assert I18n.exists?('members.deletion_blocked', locale)
      end
    end
  end
end
