# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class ImportBomTest < ActionDispatch::IntegrationTest
  setup do
    login_as(users(:user1), scope: :user)
  end

  test 'accepts a UTF-8 BOM CSV and updates the member identified by its first column' do
    member = users(:user2)
    original_count = User.count

    with_upload('.csv') do |upload|
      post '/api/imports/members', params: { import_members: upload, update_field: 'id' }, headers: default_headers

      assert_equal 201, response.status, response.body
      import = Import.find(json_response(response.body)[:id])
      begin
        MembersImportWorker.new.perform(import.id)

        results = import.reload.results_hash
        assert_equal member.id.to_s, results[0][:row]['id']
        assert_equal 'update', results[1][:status]
        assert_equal member.id, results[1][:user]
        assert_equal true, results[1][:result]
        assert_equal '0123456789', member.profile.reload.phone
        assert_equal original_count, User.count
      ensure
        import.remove_attachment!
        import.destroy!
      end
    end
  end

  test 'still rejects non-CSV extensions even when the detected content type is plain text' do
    with_upload('.txt') do |upload|
      assert_no_difference 'Import.count' do
        post '/api/imports/members', params: { import_members: upload, update_field: 'id' }, headers: default_headers
      end

      assert_equal 422, response.status
      assert_not_empty json_response(response.body)[:attachment]
    end
  end

  private

  def with_upload(extension)
    Tempfile.create(['members-bom', extension]) do |file|
      file.binmode
      file.write("\xEF\xBB\xBF".b + "id;phone\n#{users(:user2).id};0123456789\n".b)
      file.flush
      yield Rack::Test::UploadedFile.new(file.path, 'text/csv')
    end
  end
end
