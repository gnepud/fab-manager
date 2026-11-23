# frozen_string_literal: true

# Remove persisted identities for children deleted before booking anonymization.
class AnonymizeOrphanedChildBookings < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE booking_users
      SET name = NULL, booked_type = NULL, booked_id = NULL
      WHERE booked_type = 'Child'
        AND NOT EXISTS (SELECT 1 FROM children WHERE children.id = booking_users.booked_id)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Deleted child identities cannot be restored'
  end
end
