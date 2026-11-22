# frozen_string_literal: true

require 'test_helper'

class TrainingAuthorizationDateMailerTest < ActionMailer::TestCase
  setup do
    @training = Training.find(4)
    @member = User.find(9)
    @granted_at = Time.zone.local(2026, 9, 22, 0, 15)
    travel_to Time.zone.local(2026, 11, 22, 12)
  end

  { authorization_expired: 'Authorization', invalidated: 'Invalidation' }.each do |type, service|
    %i[en fr].each do |locale|
      test "#{type} email in #{locale} preserves the grant date after authorization deletion" do
        configure_training(service)
        authorization = StatisticProfileTraining.create!(statistic_profile: @member.statistic_profile,
                                                         training: @training, created_at: @granted_at)

        if service == 'Authorization'
          Trainings::AuthorizationService.auto_cancel_authorizations(@training)
        else
          Trainings::InvalidationService.auto_invalidate(@training)
        end

        assert_not StatisticProfileTraining.exists?(authorization.id)
        notification = Notification.find_by!(receiver: @member, attached_object: @training,
                                             notification_type_id: notification_type(type).id)
        body = email_body(notification.reload, locale)
        assert_includes body, I18n.l(@granted_at.to_date, locale: locale)
        assert_equal @granted_at, Time.zone.parse(notification.get_meta_data(:authorization_created_at))

        travel_to Time.zone.local(2026, 12, 22, 12)
        @training.update!(authorization_period: 2, invalidation_period: 2)
        assert_includes email_body(notification.reload, locale), I18n.l(@granted_at.to_date, locale: locale)
      end

      test "legacy #{type} email in #{locale} does not invent an unknown grant date" do
        configure_training(service)
        [nil, {}, { authorization_created_at: '' }].each do |metadata|
          notification = Notification.create!(receiver: @member, attached_object: @training,
                                              notification_type: notification_type(type), meta_data: metadata)

          body = email_body(notification.reload, locale)
          assert_includes body, '—'
          assert_not_includes body, I18n.l(1.month.ago.to_date, locale: locale)
        end
      end
    end
  end

  private

  def configure_training(service)
    @training.update!(authorization: service == 'Authorization', authorization_period: 1,
                      invalidation: service == 'Invalidation', invalidation_period: 1)
  end

  def notification_type(type)
    NotificationType.find_by!(name: "notify_member_training_#{type}")
  end

  def email_body(notification, locale)
    email = I18n.with_locale(locale) { NotificationsMailer.send_mail_by(notification).message }
    assert_equal [@member.email], email.to
    Nokogiri::HTML(email.body.decoded).text
  end
end
