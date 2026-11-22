# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class NotificationsMailerTest < ActionMailer::TestCase
  test 'the expired subscription email links to plans in English' do
    assert_includes expired_subscription_links(:en), [plans_url, 'Subscriptions']
  end

  test 'the expired subscription email links to plans in French' do
    assert_includes expired_subscription_links(:fr), [plans_url, 'Abonnements']
  end

  private

  def plans_url
    "#{Rails.application.routes.url_helpers.root_url}#!/plans"
  end

  def expired_subscription_links(locale)
    subscription = subscriptions('subscription_3')
    notification = Notification.create!(
      notification_type: NotificationType.find_by!(name: 'notify_member_subscription_is_expired'),
      receiver: subscription.user,
      attached_object: subscription
    )
    email = I18n.with_locale(locale) do
      CustomAsset.stub(:get_url, '/logo.png') { NotificationsMailer.send_mail_by(notification).message }
    end

    Nokogiri::HTML(email.body.decoded).css('a').map { |link| [link['href'], link.text] }
  end
end
