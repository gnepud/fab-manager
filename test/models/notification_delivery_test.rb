# frozen_string_literal: true

require 'test_helper'

class NotificationDeliveryTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @delivery_job = NotificationsMailer.delivery_job
    @queue_adapter = @delivery_job.queue_adapter
    @delivery_job.queue_adapter = :sidekiq
    @first_notification_id = Notification.maximum(:id) || 0
    ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.clear
  end

  teardown do
    @delivery_job.queue_adapter = @queue_adapter
    ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.clear
    Notification.where('id > ?', @first_notification_id).delete_all
  end

  test 'notification mail is enqueued only after the outer transaction commits' do
    notification = nil
    Notification.transaction do
      Notification.transaction(requires_new: true) do
        notify_member
        notification = Notification.order(:id).last
      end

      refute visible_to_worker?(notification.id)
      assert_empty mail_jobs
    end

    assert visible_to_worker?(notification.id)
    assert_equal 1, mail_jobs.size
    arguments = ActiveJob::Arguments.deserialize(mail_jobs.first['args'].first['arguments'])
    assert_equal notification, arguments.last[:args].first
  end

  test 'rolled back notifications do not enqueue mail' do
    Notification.transaction do
      notify_member
      raise ActiveRecord::Rollback
    end

    assert_empty mail_jobs
    assert_equal @first_notification_id, Notification.maximum(:id)
  end

  test 'notification mail outside a transaction is enqueued immediately' do
    notify_member

    assert_equal 1, mail_jobs.size
    assert visible_to_worker?(Notification.order(:id).last.id)
  end

  test 'invalid notifications do not enqueue mail' do
    refute Notification.new.deliver_later

    assert_empty mail_jobs
  end

  private

  def notify_member
    NotificationCenter.call(type: 'notify_member_subscription_extended', receiver: User.find(4), attached_object: Subscription.first)
  end

  def mail_jobs
    ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.jobs
  end

  def visible_to_worker?(id)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { Notification.exists?(id) }
    end.value
  end
end
