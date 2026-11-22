# frozen_string_literal: true

require 'test_helper'
require 'csv'
require 'tempfile'

class MembersImportBlankCellsTest < ActiveSupport::TestCase
  setup do
    @member = users(:user2)
    @member.update!(is_allow_contact: true, is_allow_newsletter: true)
    @member.profile.update!(phone: '0123456789')
    @member.statistic_profile.update!(gender: true)
    @member.tag_ids = [1]
    @member.statistic_profile.training_ids = [1]
  end

  test 'quoted empty cells preserve existing profile and consent values' do
    import_csv("id;gender;allow_contact;phone\n#{@member.id};\"\";\"\";\"\"\n")

    assert_equal true, @member.reload.is_allow_contact
    assert_equal true, @member.statistic_profile.reload.gender
    assert_equal '0123456789', @member.profile.reload.phone
  end

  test 'all columns treat empty quoted-empty and whitespace cells as absent' do
    headers = CSV.read(Rails.public_path.join('example.csv'), col_sep: ';').first
    before = member_attributes

    [nil, '', " \t "].each do |blank|
      values = headers.map { |header| header == 'id' ? @member.id : blank }
      csv = CSV.generate(col_sep: ';') do |file|
        file << headers
        file << values
      end
      import_csv(csv)

      assert_equal before, member_attributes
    end
  end

  test 'nonblank cells still update values without trimming meaningful whitespace' do
    import_csv("id;gender;allow_contact;phone;job\n#{@member.id};female;no;0987654321; a job \n")

    assert_equal false, @member.reload.is_allow_contact
    assert_equal false, @member.statistic_profile.reload.gender
    assert_equal '0987654321', @member.profile.reload.phone
    assert_equal ' a job ', @member.profile.job
  end

  private

  def member_attributes
    @member.reload
    [@member, @member.profile.reload, @member.invoicing_profile.reload, @member.statistic_profile.reload].map do |record|
      record.attributes.except('updated_at')
    end + [@member.tag_ids.sort, @member.statistic_profile.training_ids.sort]
  end

  def import_csv(csv)
    Tempfile.create(['members-import', '.csv']) do |file|
      file.write(csv)
      file.flush
      import = Import.create!(attachment: Rack::Test::UploadedFile.new(file.path, 'text/csv'),
                              user: users(:user1), update_field: 'id', category: 'members')
      begin
        MembersImportWorker.new.perform(import.id)
        assert_equal true, import.reload.results_hash[1][:result]
      ensure
        import.remove_attachment!
        import.destroy!
      end
    end
  end
end
