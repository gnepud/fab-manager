# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MembersImportIdentityTest < ActiveSupport::TestCase
  %w[email username].each do |field|
    %w[unused occupied].each do |target|
      test "matching by #{field} ignores an #{target} CSV id while updating other fields" do
        member = users(:user2)
        other = users(:user1)
        other_attributes = other.attributes
        target_id = target == 'unused' ? 999_999 : other.id
        original_id = member.id
        profile_ids = [member.profile.id, member.invoicing_profile.id, member.statistic_profile.id]
        csv = "id;#{field};phone\n#{target_id};#{member.public_send(field)};0123456789\n"

        with_results(csv, field) do |results|
          assert_equal true, results[1][:result]
          assert_equal 'update', results[1][:status]
          assert_equal original_id, results[1][:user]
          assert_equal original_id, member.reload.id
          assert_equal '0123456789', member.profile.reload.phone
          assert_equal profile_ids, [member.profile.id, member.invoicing_profile.id, member.statistic_profile.id]
          assert_equal original_id, member.invoicing_profile.user_id
          assert_equal original_id, member.statistic_profile.user_id
          assert_equal other_attributes, other.reload.attributes
          assert_not User.exists?(target_id) if target == 'unused'
        end
      end
    end
  end

  test 'matching by id still updates the matched member' do
    member = users(:user2)
    with_results("id;phone\n#{member.id};0123456789\n", 'id') do |results|
      assert_equal true, results[1][:result]
      assert_equal member.id, results[1][:user]
      assert_equal '0123456789', member.profile.reload.phone
    end
  end

  test 'creation retains an explicitly supplied id' do
    csv = "id;email;username;first_name;last_name;group\n" \
          "999999;new-identity@example.com;new-identity;Jane;Example;standard\n"
    with_results(csv, 'email') do |results|
      assert_equal true, results[1][:result]
      assert_equal 'create', results[1][:status]
      assert_equal 999_999, results[1][:user]
      assert_equal 'new-identity@example.com', User.find(999_999).email
    end
  end

  private

  def with_results(csv, update_field)
    Tempfile.create(['members-import', '.csv']) do |file|
      file.write(csv)
      file.flush
      import = Import.create!(attachment: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
                              user: users(:user1), update_field: update_field, category: 'members')
      begin
        MembersImportWorker.new.perform(import.id)
        yield import.reload.results_hash
      ensure
        import.remove_attachment!
        import.destroy!
      end
    end
  end
end
