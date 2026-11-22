# frozen_string_literal: true

require 'test_helper'

class StatisticProfileTrainingTest < ActiveSupport::TestCase
  setup do
    @profile = User.find(9).statistic_profile
    @training = Training.find(3)
  end

  test 'duplicate authorizations are invalid' do
    @profile.grant_training(@training)
    duplicate = StatisticProfileTraining.new(statistic_profile: @profile, training: @training)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:training_id, :taken, value: @training.id)
  end

  test 'database rejects duplicate authorizations even without validations' do
    @profile.grant_training(@training)

    assert_raises ActiveRecord::RecordNotUnique do
      StatisticProfileTraining.transaction(requires_new: true) do
        attributes = { statistic_profile_id: @profile.id, training_id: @training.id }
        StatisticProfileTraining.insert_all!([attributes]) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  test 'a stale association is refreshed before replacing training ids' do
    @profile.trainings.load
    grant = StatisticProfile.find(@profile.id).grant_training(@training)

    @profile.training_ids = [@training.id, @training.id.to_s]

    assert_equal [grant.id], @profile.statistic_profile_trainings.pluck(:id)
  end

  test 'new profiles normalize repeated training ids before saving' do
    profile = StatisticProfile.new(user: User.find(9), group: Group.first, role: Role.find_by!(name: 'member'))
    profile.training_ids = ['', @training.id, @training.id.to_s]
    profile.save!

    assert_equal [@training.id], profile.trainings.pluck(:id)
  end
end
