# frozen_string_literal: true

require 'test_helper'

class TrainingGrantsTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    @member = User.find(9)
    @training = Training.find(3)
    @notification_type = NotificationType.find_by!(name: 'notify_user_training_valid')
  end

  teardown do
    Warden.test_reset!
  end

  %w[admin manager].each do |role|
    test "#{role} repeatedly granting a training creates one authorization and notification" do
      login_operator(role)

      assert_difference -> { grants.count } => 1, -> { notifications.count } => 1 do
        4.times do
          put "/api/trainings/#{@training.id}", params: { training: { users: [@member.id] } }.to_json, headers: default_headers
          assert_response :no_content
        end
      end
    end

    test "#{role} saving duplicate training ids repeatedly creates one authorization and notification" do
      login_operator(role)

      assert_difference -> { grants.count } => 1, -> { notifications.count } => 1 do
        3.times do
          patch "/api/members/#{@member.id}", params: {
            user: { statistic_profile_attributes: { id: @member.statistic_profile.id, gender: false,
                                                    training_ids: [@training.id, @training.id.to_s] } }
          }.to_json, headers: default_headers
          assert_response :success
        end
      end
      assert_not @member.statistic_profile.reload.gender
    end
  end

  test 'saving an existing authorization preserves its grant date and emits no notification' do
    login_operator('admin')
    grant = StatisticProfileTraining.create!(statistic_profile: @member.statistic_profile, training: @training, created_at: 2.months.ago)
    granted_at = grant.reload.created_at

    assert_no_difference -> { grants.count } do
      assert_no_difference -> { notifications.count } do
        put "/api/trainings/#{@training.id}", params: { training: { users: [@member.id] } }.to_json, headers: default_headers
        assert_response :no_content
        assert_no_enqueued_jobs only: NotificationMailDeliveryJob do
          patch "/api/members/#{@member.id}", params: {
            user: { statistic_profile_attributes: { id: @member.statistic_profile.id, training_ids: [@training.id, @training.id] } }
          }.to_json, headers: default_headers
          assert_response :success
        end
      end
    end
    assert_equal granted_at, grant.reload.created_at
  end

  test 'member editing still removes deselected authorizations' do
    login_operator('admin')
    StatisticProfileTraining.create!(statistic_profile: @member.statistic_profile, training: @training)

    patch "/api/members/#{@member.id}", params: {
      user: { statistic_profile_attributes: { id: @member.statistic_profile.id, training_ids: [] } }
    }.to_json, headers: default_headers

    assert_response :success
    assert_empty grants
  end

  private

  def login_operator(role)
    operator = User.find(role == 'admin' ? 1 : 5)
    operator.add_role(:manager) if role == 'manager'
    login_as(operator, scope: :user)
  end

  def grants
    StatisticProfileTraining.where(statistic_profile: @member.statistic_profile, training: @training)
  end

  def notifications
    Notification.where(receiver: @member, notification_type_id: @notification_type.id)
  end
end
