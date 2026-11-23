# frozen_string_literal: true

require 'test_helper'

class TrainingGrantConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @profile = User.find(9).statistic_profile
    @training = Training.find(3)
    @notification_type = NotificationType.find_by!(name: 'notify_user_training_valid')
  end

  teardown do
    @profile.statistic_profile_trainings.destroy_all
  end

  test 'concurrent grants create exactly one authorization and notification' do
    assert_concurrent_grants(false)
  end

  test 'concurrent grants and training id replacement share the same lock' do
    assert_concurrent_grants(true)
  end

  private

  def assert_concurrent_grants(mixed)
    ready = Queue.new
    start = Queue.new
    before = Notification.where(receiver: @profile.user, notification_type_id: @notification_type.id).count
    threads = 4.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.cache do
            profile = StatisticProfile.find(@profile.id)
            profile.trainings.load
            ready << true
            start.pop
            if mixed && index.even?
              profile.training_ids = [@training.id, @training.id.to_s]
            else
              profile.grant_training(@training)
            end
          end
        end
      end
    end
    4.times { ready.pop }
    4.times { start << true }
    threads.each(&:value)

    assert_equal 1, @profile.statistic_profile_trainings.where(training: @training).count
    Notification.uncached do
      assert_equal before + 1, Notification.where(receiver: @profile.user, notification_type_id: @notification_type.id).count
    end
  end
end
