# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MembersImportAssociationIdsTest < ActiveSupport::TestCase
  setup do
    @member = users(:user2)
    @member.tag_ids = [tags('tag_1').id]
    @member.statistic_profile.training_ids = [trainings('training_1').id]
  end

  test 'unknown tag and training IDs fail the row without changing associations or other fields' do
    original_phone = @member.profile.phone
    with_results("id;tags;trainings;phone\n#{@member.id};999999;999998;0123456789\n") do |results|
      assert_equal false, results[1][:result]
      assert_equal 'update', results[1][:status]
      assert_match(/999999/, results[2][:tags].join)
      assert_match(/999998/, results[2][:trainings].join)
      assert_original_associations
      assert_equal original_phone, @member.profile.reload.phone
    end
  end

  test 'mixed known and unknown IDs fail but the next valid row is imported' do
    csv = "id;tags;trainings\n#{@member.id};1,999999;2\n#{@member.id};2;2\n"
    with_results(csv) do |results|
      assert_equal false, results[1][:result]
      assert_match(/999999/, results[2][:tags].join)
      assert_equal true, results[4][:result]
      assert_equal [2], @member.reload.tag_ids
      assert_equal [2], @member.statistic_profile.reload.training_ids
    end
  end

  test 'an unknown training ID does not apply valid tags' do
    with_results("id;tags;trainings\n#{@member.id};2;999999\n") do |results|
      assert_equal false, results[1][:result]
      assert_match(/999999/, results[2][:trainings].join)
      assert_original_associations
    end
  end

  test 'empty association cells preserve existing associations' do
    with_results("id;tags;trainings\n#{@member.id};;\n") do |results|
      assert_equal true, results[1][:result]
      assert_original_associations
    end
  end

  private

  def assert_original_associations
    assert_equal [1], @member.reload.tag_ids
    assert_equal [1], @member.statistic_profile.reload.training_ids
  end

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
