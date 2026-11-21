# frozen_string_literal: true

require 'test_helper'

class SettingsTest < ActionDispatch::IntegrationTest
  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @admin = User.find_by(username: 'admin')
    login_as(@admin, scope: :user)
  end

  test 'update setting value' do
    put '/api/settings/fablab_name',
        params: {
          setting: {
            value: 'Test Fablab'
          }
        }
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type
    resp = json_response(response.body)
    assert_equal 'fablab_name', resp[:setting][:name]
    assert_equal 'Test Fablab', resp[:setting][:value]

    # Check record
    setting = Setting.find_by(name: resp[:setting][:name])
    assert_not_nil setting, 'setting was not found in database'
    assert_equal 2, setting.history_values.count, 'all historical values were not found'
    assert_includes setting.history_values.map(&:value), 'Fab Lab de La Casemate', 'previous parameter was not saved'
    assert_includes setting.history_values.map(&:value), 'Test Fablab', 'current parameter was not saved'
  end

  test 'bulk update some settings' do
    patch '/api/settings/bulk_update',
          params: {
            settings: [
              { name: 'fablab_name', value: 'Test Fablab' },
              { name: 'name_genre', value: 'male' },
              { name: 'main_color', value: '#ea519a' }
            ]
          }
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type
    resp = json_response(response.body)
    assert(resp[:settings].any? { |s| s[:name] == 'fablab_name' && s[:value] == 'Test Fablab' })
    assert(resp[:settings].any? { |s| s[:name] == 'name_genre' && s[:value] == 'male' })
    assert(resp[:settings].any? { |s| s[:name] == 'main_color' && s[:value] == '#ea519a' })
  end

  test 'transactional bulk update fails' do
    old_css = Setting.get('home_css')
    old_color = Setting.get('main_color')

    patch '/api/settings/bulk_update?transactional=true',
          params: {
            settings: [
              { name: 'home_css', value: 'INVALID CSS{{!!' },
              { name: 'main_color', value: '#ea519a' }
            ]
          }
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type
    resp = json_response(response.body)
    assert_not_nil resp[:settings].first[:error]
    assert_match(/Error: Invalid CSS after/, resp[:settings].first[:error].first)

    # Check values havn't changed
    assert_equal old_css, Setting.get('home_css')
    assert_equal old_color, Setting.get('main_color')
  end

  test 'update setting with wrong name' do
    put '/api/settings/does_not_exists',
        params: {
          setting: {
            value: 'ERROR EXPECTED'
          }
        }
    assert_equal 422, response.status
    assert_match(/Name is not included in the list/, response.body)
  end

  test 'show setting' do
    get '/api/settings/fablab_name'

    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type
    resp = json_response(response.body)
    assert_equal 'fablab_name', resp[:setting][:name], 'wrong parameter name'
    assert_equal 'Fab Lab de La Casemate', resp[:setting][:value], 'wrong parameter value'
  end

  test 'booking window rejects inverted and equal hours' do
    set_booking_window('08:00', '12:00')

    [['booking_window_start', '13:00'], ['booking_window_start', '12:00'],
     ['booking_window_end', '07:00'], ['booking_window_end', '08:00']].each do |name, time|
      put "/api/settings/#{name}", params: { setting: { value: "2001-02-03T#{time}:00.000Z" } }
      assert_response :unprocessable_entity
      assert_equal I18n.t('settings.invalid_booking_window'), json_response(response.body)[:error]
    end

    assert_equal 8, Time.zone.parse(Setting.get('booking_window_start')).utc.hour
    assert_equal 12, Time.zone.parse(Setting.get('booking_window_end')).utc.hour
  end

  test 'booking window accepts valid hours and a bulk move past the old closing time' do
    set_booking_window('08:00', '12:00')
    put '/api/settings/booking_window_start', params: { setting: { value: '2001-02-03T09:00:00.000Z' } }
    assert_response :ok

    patch '/api/settings/bulk_update', params: { settings: [
      { name: 'booking_window_start', value: '2000-01-01T14:00:00.000Z' },
      { name: 'booking_window_end', value: '2000-01-01T18:00:00.000Z' }
    ] }
    assert_response :ok
    assert json_response(response.body)[:settings].none? { |setting| setting[:error] }
    assert_equal 14, Time.zone.parse(Setting.get('booking_window_start')).utc.hour
    assert_equal 18, Time.zone.parse(Setting.get('booking_window_end')).utc.hour
  end

  test 'booking window rejects empty and malformed times' do
    set_booking_window('08:00', '12:00')
    ['', 'not a time'].each do |value|
      put '/api/settings/booking_window_start', params: { setting: { value: value } }
      assert_response :unprocessable_entity
    end
    assert_equal 8, Time.zone.parse(Setting.get('booking_window_start')).utc.hour
  end

  test 'booking window accepts local hours crossing midnight UTC' do
    Time.use_zone('Europe/Paris') do
      set_booking_window('00:00', '07:00')
      put '/api/settings/booking_window_start', params: { setting: { value: '2000-01-01T23:30:00.000Z' } }

      assert_response :ok
      assert_equal '00:30', Time.zone.parse(Setting.get('booking_window_start')).strftime('%H:%M')
      assert_equal '08:00', Time.zone.parse(Setting.get('booking_window_end')).strftime('%H:%M')
    end
  end

  test 'bulk update rejects an inverted booking window' do
    set_booking_window('08:00', '12:00')
    patch '/api/settings/bulk_update', params: { settings: [
      { name: 'booking_window_start', value: '2000-01-01T16:00:00.000Z' },
      { name: 'booking_window_end', value: '2000-01-01T15:00:00.000Z' }
    ] }
    assert_response :ok
    assert json_response(response.body)[:settings].all? { |setting| setting[:error].present? }
    assert_equal 8, Time.zone.parse(Setting.get('booking_window_start')).utc.hour
    assert_equal 12, Time.zone.parse(Setting.get('booking_window_end')).utc.hour
  end

  private

  def set_booking_window(start_time, end_time)
    { 'booking_window_start' => start_time, 'booking_window_end' => end_time }.each do |name, time|
      setting = Setting.find_or_create_by!(name: name)
      SettingService.save_and_update(setting, "2000-01-01T#{time}:00.000Z", @admin)
    end
  end
end
