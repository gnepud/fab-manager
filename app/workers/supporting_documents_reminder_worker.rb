# frozen_string_literal: true

# Send a notification to users who did not upload their supporting document files yet
class SupportingDocumentsReminderWorker
  include Sidekiq::Worker

  def perform
    users_to_notify = User.members
                          .supporting_documents_reminder_not_sent
                          .where("users.created_at < ?", 2.days.ago)
                          .where(<<~SQL.squish)
                            EXISTS (
                              SELECT 1 FROM supporting_document_types_groups
                              WHERE supporting_document_types_groups.group_id = users.group_id
                                AND NOT EXISTS (
                                  SELECT 1 FROM supporting_document_files
                                  WHERE supporting_document_files.supportable_id = users.id
                                    AND supporting_document_files.supportable_type = 'User'
                                    AND supporting_document_files.supporting_document_type_id =
                                        supporting_document_types_groups.supporting_document_type_id
                                )
                            )
                          SQL
    users_to_notify.each do |user|
      NotificationCenter.call type: 'notify_user_supporting_document_reminder',
                              receiver: user,
                              attached_object: user
      user.update_column(:supporting_documents_reminder_sent_at, DateTime.current)
    end
  end
end
