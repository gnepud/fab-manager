# frozen_string_literal: true

require 'test_helper'
require 'minitest/autorun'
#require 'sidekiq/testing'

class SupportingDocumentsReminderWorkerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    @worker = SupportingDocumentsReminderWorker.new

    group = groups(:group_1)
    @users = User.where(group_id: group.id).members
    @supporting_document_type_1 = SupportingDocumentType.create!(name: "doc1", groups: [group])
    @supporting_document_type_2 = SupportingDocumentType.create!(name: "doc2", groups: [group])
  end

  test 'do nothing if it concerns another group' do
    group = Group.create!(name: 'test', slug: 'test')
    SupportingDocumentType.destroy_all
    supporting_document_type = SupportingDocumentType.create!(name: "doc3", groups: [group])

    @users.each do |user|
      assert_nil user.supporting_documents_reminder_sent_at
    end
    assert_enqueued_emails 0 do
      @worker.perform
    end
    @users.reload.each do |user|
      assert_nil user.supporting_documents_reminder_sent_at
    end
  end

  test 'notify every users who did not upload supporting document files' do
    @users.each do |user|
      assert_nil user.supporting_documents_reminder_sent_at
    end

    assert_enqueued_emails @users.length do
      @worker.perform
    end

    @users.reload.each do |user|
      assert user.supporting_documents_reminder_sent_at
    end

    assert_enqueued_emails 0 do
      @worker.perform
    end
  end

  test 'notify users even if they have uploaded 1 document of the 2' do
    @users.each do |user|
      user.supporting_document_files.create!(supporting_document_type: @supporting_document_type_1,
                                             attachment: fixture_file_upload('document.pdf'))
    end

    assert_enqueued_emails @users.length do
      @worker.perform
    end
  end

  test 'do not notify users if they have uploaded all documents' do
    @users.each do |user|
      user.supporting_document_files.create!(supporting_document_type: @supporting_document_type_1,
                                             attachment: fixture_file_upload('document.pdf'))
      user.supporting_document_files.create!(supporting_document_type: @supporting_document_type_2,
                                             attachment: fixture_file_upload('document.pdf'))
    end

    assert_enqueued_emails 0 do
      @worker.perform
    end
  end

  test 'do not notify users if they were created too recently' do
    @users.update_all(created_at: 2.minutes.ago)

    assert_enqueued_emails 0 do
      @worker.perform
    end
  end

  test 'notify transferred members missing a document required by their current group' do
    user = @users.first
    previous_group = Group.create!(name: 'Previous group', slug: 'previous-group')
    previous_type = SupportingDocumentType.create!(name: 'Previous document', groups: [previous_group])
    user.update!(group: previous_group)
    user.supporting_document_files.create!(supporting_document_type: previous_type,
                                           attachment: fixture_file_upload('document.pdf'))
    user.update!(group: groups(:group_1))

    assert_enqueued_emails @users.length do
      @worker.perform
    end
    assert user.reload.supporting_documents_reminder_sent_at
  end

  test 'send exactly one reminder to a member missing two required documents' do
    user = @users.first
    User.members.where.not(id: user.id).update_all(supporting_documents_reminder_sent_at: Time.current)

    assert_enqueued_emails 1 do
      @worker.perform
    end
    assert user.reload.supporting_documents_reminder_sent_at

    assert_enqueued_emails 0 do
      @worker.perform
    end
  end
end
