# frozen_string_literal: true

require 'test_helper'

class ICalendarEventsTest < ActionDispatch::IntegrationTest
  setup do
    @calendar = i_calendars(:one)
    i_calendar_events(:one).update!(i_calendar: @calendar, summary: 'Imported event')
  end

  test 'lets events inherit the configured source color' do
    @calendar.update!(color: '#2458a6', text_color: '#ffffff')

    event = public_event

    assert_not event.key?(:backgroundColor), "event background #{event[:backgroundColor].inspect} overrides the source color"
    assert_equal 'Imported event', event[:title]
  end

  test 'keeps the white background when no source color is set' do
    @calendar.update!(color: '', text_color: nil)

    assert_equal 'white', public_event[:backgroundColor]
  end

  test 'keeps dark text readable on a dark source' do
    @calendar.update!(color: '#151515', text_color: '#111')

    assert_equal 'white', public_event[:backgroundColor]
  end

  test 'keeps the default black text readable on a black source' do
    @calendar.update!(color: '#000', text_color: nil)

    assert_equal 'white', public_event[:backgroundColor]
  end

  test 'uses a dark fallback when the configured colors are both light' do
    @calendar.update!(color: '#eee', text_color: '#fff')

    assert_equal 'black', public_event[:backgroundColor]
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
