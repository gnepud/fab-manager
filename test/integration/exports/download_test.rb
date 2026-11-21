# frozen_string_literal: true

require 'test_helper'

module Exports; end

class Exports::DownloadTest < ActionDispatch::IntegrationTest
  test 'download returns a localized 404 when the export file has been deleted' do
    admin = User.with_role(:admin).first
    login_as(admin, scope: :user)
    export = Export.create!(user: admin, category: 'statistics', export_type: 'global', extension: 'xlsx')
    path = Rails.root.join(export.file)
    download_url = "/api/exports/#{export.id}/download"
    File.binwrite(path, 'export contents')

    get download_url

    assert_response :ok
    assert_equal 'export contents', response.body
    assert_match(/\Aattachment;/, response.headers['Content-Disposition'])

    File.delete(path)

    get download_url, params: { locale: :fr }

    assert_response :not_found
    assert_equal 'text/plain', response.media_type
    assert_equal I18n.t('errors.messages.export_not_found', locale: :fr), response.body
  ensure
    FileUtils.rm_f(path) if path
  end
end
