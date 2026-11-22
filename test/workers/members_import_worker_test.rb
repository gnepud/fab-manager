# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MembersImportWorkerTest < ActiveSupport::TestCase
  test 'records an invalid row and continues importing before notifying the admin' do
    member = users(:user2)
    csv = "id;group;phone\n#{member.id};nonexistent-import-group;1111111111\n#{member.id};;0123456789\n"

    with_import(csv) do |import|
      MembersImportWorker.new.perform(import.id)

      results = import.reload.results_hash
      assert_equal 'nonexistent-import-group', results[0][:row]['group']
      assert_match(/nonexistent-import-group/, results[1])
      assert_equal member.id.to_s, results[2][:row]['id']
      assert_equal 'update', results[3][:status]
      assert_equal true, results[3][:result]
      assert_equal '0123456789', member.profile.reload.phone
      assert_completion_notification(import)
    end
  end

  test 'persists completed rows and a readable error when CSV parsing fails' do
    member = users(:user2)
    csv = "id;phone\n#{member.id};0123456789\n\"unterminated\n"

    with_import(csv) do |import|
      MembersImportWorker.new.perform(import.id)

      results = import.reload.results_hash
      assert_equal true, results[1][:result]
      assert_match(/Unclosed quoted field/, results.last)
      assert_equal '0123456789', member.profile.reload.phone
      assert_completion_notification(import)
    end
  end

  test 'finishes an empty import and notifies the admin' do
    with_import("id;phone\n") do |import|
      MembersImportWorker.new.perform(import.id)

      assert_equal [], import.reload.results_hash
      assert_completion_notification(import)
    end
  end

  private

  def with_import(csv)
    Tempfile.create(['members-import', '.csv']) do |file|
      file.write(csv)
      file.flush
      import = Import.create!(attachment: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
                              user: users(:user1), update_field: 'id', category: 'members')
      begin
        yield import
      ensure
        import.remove_attachment!
        import.destroy!
      end
    end
  end

  def assert_completion_notification(import)
    type = NotificationType.find_by!(name: 'notify_admin_import_complete')
    assert Notification.exists?(attached_object: import, receiver: users(:user1), notification_type_id: type.id)
  end
end
