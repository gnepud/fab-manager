# frozen_string_literal: true

# Enforce one authorization per member and training.
class DeduplicateTrainingAuthorizations < ActiveRecord::Migration[7.2]
  INDEX_NAME = 'index_statistic_profile_trainings_on_profile_and_training'

  def up
    execute 'LOCK TABLE statistic_profile_trainings IN SHARE ROW EXCLUSIVE MODE'

    duplicate_ids = <<~SQL.squish
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (
          PARTITION BY statistic_profile_id, training_id ORDER BY created_at, id
        ) AS position
        FROM statistic_profile_trainings
      ) authorizations WHERE position > 1
    SQL

    execute <<~SQL.squish
      DELETE FROM notifications
      WHERE attached_object_type = 'StatisticProfileTraining'
        AND attached_object_id IN (#{duplicate_ids})
    SQL
    execute "DELETE FROM statistic_profile_trainings WHERE id IN (#{duplicate_ids})"

    add_index :statistic_profile_trainings, %i[statistic_profile_id training_id], unique: true, name: INDEX_NAME
  end

  def down
    remove_index :statistic_profile_trainings, name: INDEX_NAME
  end
end
