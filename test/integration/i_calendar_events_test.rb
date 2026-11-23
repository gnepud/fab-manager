# frozen_string_literal: true

require 'test_helper'

class ICalendarEventsTest < ActionDispatch::IntegrationTest
  setup do
    @calendar = i_calendars(:one)
    i_calendar_events(:one).update!(i_calendar: @calendar, summary: 'Imported event')
  end

  test 'uses the configured source color for the event background' do
    @calendar.update!(color: '#2458a6', text_color: '#ffffff')

    event = public_event

    assert_equal '#2458a6', event[:backgroundColor]
    assert_equal 'Imported event', event[:title]
  end

  test 'keeps the white background when no source color is set' do
    @calendar.update!(color: '')

    assert_equal 'white', public_event[:backgroundColor]
  end

  private

  def public_event
    get "/api/i_calendar/#{@calendar.id}/events", params: { start: '2019-12-02', end: '2019-12-03', timezone: 'UTC' }, headers: default_headers

    assert_response :success
    events = json_response(response.body)
    assert_equal 1, events.size
    events.first
  end
end
