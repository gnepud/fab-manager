# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MembersImportBirthdateTest < ActiveSupport::TestCase
  setup do
    @member = users(:user2)
    @member.statistic_profile.update!(birthday: Date.new(1980, 1, 1))
    @member.profile.update!(phone: '0123456789')
  end

  test 'invalid dates fail updates without changing the member' do
    ['not-a-date', '2023-02-29'].each do |birthdate|
      with_results("id;birthdate;phone\n#{@member.id};#{birthdate};0987654321\n") do |results|
        assert_equal false, results[1][:result]
        assert_equal 'update', results[1][:status]
        assert_includes results[2][:birthdate].join, birthdate
        assert_equal Date.new(1980, 1, 1), @member.statistic_profile.reload.birthday
        assert_equal '0123456789', @member.profile.reload.phone
      end
    end
  end

  test 'invalid dates prevent new member creation' do
    csv = "email;username;first_name;last_name;group;birthdate\n" \
          "invalid-date@example.com;invalid-date;Jane;Example;standard;not-a-date\n"

    assert_no_difference 'User.count' do
      with_results(csv) do |results|
        assert_equal false, results[1][:result]
        assert_equal 'create', results[1][:status]
        assert_nil results[1][:user]
        assert_includes results[2][:birthdate].join, 'not-a-date'
      end
    end
  end

  test 'continues after an invalid date and applies a valid ISO date' do
    csv = "id;birthdate\n#{@member.id};not-a-date\n#{@member.id};2000-02-29\n"

    with_results(csv) do |results|
      assert_equal false, results[1][:result]
      assert_equal 'update', results[4][:status]
      assert_equal true, results[4][:result]
      assert_equal Date.new(2000, 2, 29), @member.statistic_profile.reload.birthday
    end
  end

  test 'an empty birthdate preserves the existing birthday' do
    with_results("id;birthdate\n#{@member.id};\n") do |results|
      assert_equal true, results[1][:result]
      assert_equal Date.new(1980, 1, 1), @member.statistic_profile.reload.birthday
    end
  end

  private

  def with_results(csv)
    Tempfile.create(['members-import', '.csv']) do |file|
      file.write(csv)
      file.flush
      import = Import.create!(attachment: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
                              user: users(:user1), update_field: 'id', category: 'members')
      begin
        MembersImportWorker.new.perform(import.id)
        yield import.reload.results_hash
        type = NotificationType.find_by!(name: 'notify_admin_import_complete')
        assert Notification.exists?(attached_object: import, receiver: users(:user1), notification_type_id: type.id)
      ensure
        import.remove_attachment!
        import.destroy!
      end
    end
  end
end
