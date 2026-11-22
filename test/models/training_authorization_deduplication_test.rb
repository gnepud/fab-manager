# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('db/migrate/20261122224000_deduplicate_training_authorizations')

class TrainingAuthorizationDeduplicationTest < ActiveSupport::TestCase
  %w[authorization_expired invalidated].each do |type|
    test "deduplication preserves the oldest grant and produces one #{type} notice" do
      profile = User.find(9).statistic_profile
      training = Training.find(4)
      training.update!(authorization: type == 'authorization_expired', authorization_period: 1,
                       invalidation: type == 'invalidated', invalidation_period: 1)
      newer = StatisticProfileTraining.create!(statistic_profile: profile, training: training, created_at: 2.months.ago)
      migration = DeduplicateTrainingAuthorizations.new
      migration.down
      attributes = { statistic_profile_id: profile.id, training_id: training.id, created_at: 3.months.ago }
      result = StatisticProfileTraining.insert_all!([attributes]) # rubocop:disable Rails/SkipsModelValidations
      oldest = StatisticProfileTraining.find(result.rows.first.first)
      Notification.create!(notification_type: NotificationType.find_by!(name: 'notify_user_training_valid'),
                           receiver: profile.user, attached_object: oldest)

      migration.up

      assert_equal [oldest.id], profile.statistic_profile_trainings.where(training: training).pluck(:id)
      assert_not Notification.exists?(attached_object_type: 'StatisticProfileTraining', attached_object_id: newer.id)
      assert Notification.exists?(attached_object: oldest)
      assert_no_difference 'Notification.count' do
        profile.training_ids = [training.id, training.id]
      end

      notification_type = NotificationType.find_by!(name: "notify_member_training_#{type}")
      assert_difference -> { Notification.where(receiver: profile.user, notification_type_id: notification_type.id).count }, 1 do
        if type == 'authorization_expired'
          Trainings::AuthorizationService.auto_cancel_authorizations(training)
        else
          Trainings::InvalidationService.auto_invalidate(training)
        end
      end
      assert_empty profile.statistic_profile_trainings.where(training: training)
    end
  end
end
