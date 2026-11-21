# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require Rails.root.join('db/migrate/20261121210000_allow_stl_cad_mime_types')

class ProjectCaoTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join('db/seeds/settings.rb')
  end

  test 'STL attachments accept browser MIME variants' do
    %w[model/stl application/sla application/vnd.ms-pki.stl model/x.stl-binary model/x.stl-ascii application/octet-stream].each do |type|
      cao = ProjectCao.new(attachment: fixture_file_upload('triangle.stl', type))

      assert cao.valid?, "#{type}: #{cao.errors.full_messages.join(', ')}"
      assert_equal type, cao.attachment.content_type
    ensure
      cao&.attachment&.remove!
    end
  end

  test 'CAD attachments still reject disallowed content types' do
    cao = ProjectCao.new(attachment: fixture_file_upload('triangle.stl', 'application/x-executable'))

    assert_not cao.valid?
    assert cao.errors[:attachment].any?
  end

  test 'a project CAD attachment can be empty' do
    assert ProjectCao.new.valid?
  end

  test 'migration preserves custom MIME types and is idempotent' do
    original = 'application/x-custom  application/sla model/stl'
    Setting.set('allowed_cad_mime_types', original)

    AllowStlCadMimeTypes.new.up
    expected = "#{original} application/vnd.ms-pki.stl model/x.stl-binary model/x.stl-ascii"
    assert_equal expected, Setting.get('allowed_cad_mime_types')
    assert_no_difference('HistoryValue.count') { AllowStlCadMimeTypes.new.up }

    cao = ProjectCao.new(attachment: fixture_file_upload('triangle.stl', 'model/stl'))
    assert cao.valid?, cao.errors.full_messages.join(', ')
  ensure
    cao&.attachment&.remove!
  end

  test 'migration handles an empty setting' do
    Setting.set('allowed_cad_mime_types', '')

    AllowStlCadMimeTypes.new.up

    assert_equal AllowStlCadMimeTypes::MIME_TYPES.join(' '), Setting.get('allowed_cad_mime_types')
  end

  test 'migration leaves a missing setting for seeds to populate' do
    Setting.stub(:find_by, nil) do
      assert_no_difference('HistoryValue.count') { AllowStlCadMimeTypes.new.up }
    end
  end
end
