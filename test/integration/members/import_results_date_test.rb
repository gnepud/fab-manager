# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class ImportResultsDateTest < ActionDispatch::IntegrationTest
  setup do
    login_as(users(:user1), scope: :user)
  end

  {
    'a valid ISO birthdate' => ['1990-12-31'],
    'mixed valid dates and an invalid calendar date' => ['31/12/1990', '2023-02-29', '1990-12-31']
  }.each do |scenario, birthdates|
    test "#{scenario} remain strings in persisted results and render through the API" do
      member = users(:user2)
      Tempfile.create(['members-results-date', '.csv']) do |file|
        file.write("id;birthdate\n#{birthdates.map { |birthdate| "#{member.id};#{birthdate}\n" }.join}")
        file.flush
        post '/api/imports/members', params: {
          import_members: Rack::Test::UploadedFile.new(file.path, 'text/csv'), update_field: 'id'
        }, headers: default_headers
        assert_equal 201, response.status, response.body
        import = Import.find(json_response(response.body)[:id])
        begin
          MembersImportWorker.new.perform(import.id)

          assert_equal Date.new(1990, 12, 31), member.statistic_profile.reload.birthday
          results = import.reload.results_hash
          rows = results.filter_map { |entry| entry[:row] }
          assert_equal birthdates, rows.pluck('birthdate')
          assert_equal true, results.last[:result]

          get "/api/imports/#{import.id}", headers: default_headers
          assert_equal 200, response.status, response.body
          results = json_response(json_response(response.body)[:results])
          rows = results.filter_map { |entry| entry[:row] }
          assert_equal birthdates, rows.pluck(:birthdate)
          assert_equal true, results.last[:result]
        ensure
          import.remove_attachment!
          import.destroy!
        end
      end
    end
  end
end
