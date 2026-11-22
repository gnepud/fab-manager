# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ICalendarImportServiceTest < ActiveSupport::TestCase
  include WebMock::API

  setup do
    @calendar = i_calendars(:one)
    @calendar.update!(url: 'https://example.org/events.ics')
    @calendar.i_calendar_events.destroy_all
    @service = ICalendarImportService.new
  end

  test 'HTTP 503 after a successful import preserves cached events' do
    import_feed('first', 'second')
    cached = @calendar.i_calendar_events.reload.map(&:attributes)
    stub_request(:get, @calendar.url).to_return(status: 503, body: '<html>Service unavailable</html>')

    @service.import(@calendar.id)

    assert_equal cached, @calendar.i_calendar_events.reload.map(&:attributes)
  end

  test 'valid feeds add update and remove events including an empty calendar' do
    import_feed('first', 'second')
    assert_equal %w[first second], @calendar.i_calendar_events.order(:uid).pluck(:uid)

    import_feed('second', 'third', summary: 'Updated')
    assert_equal %w[second third], @calendar.i_calendar_events.order(:uid).pluck(:uid)
    assert_equal ['Updated'], @calendar.i_calendar_events.distinct.pluck(:summary)

    import_feed
    assert_empty @calendar.i_calendar_events.reload
  end

  test 'invalid feeds and network errors preserve events and warn' do
    import_feed('first')
    ['<html>Not a calendar</html>', "BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:invalid\nEND:VEVENT\nEND:VCALENDAR"].each do |body|
      stub_request(:get, @calendar.url).to_return(body: body)
      assert_preserved_with_warning
    end

    stub_request(:get, @calendar.url).to_timeout
    assert_preserved_with_warning
  end

  test 'worker continues importing other calendars after a failed fetch' do
    other = i_calendars(:two)
    other.update!(url: 'https://example.org/other.ics')
    other.i_calendar_events.destroy_all
    stub_request(:get, @calendar.url).to_timeout
    stub_request(:get, other.url).to_return(body: feed('other'))

    ICalendarImportWorker.new.perform([@calendar.id, other.id])

    assert_equal ['other'], other.i_calendar_events.reload.pluck(:uid)
  end

  private

  def import_feed(*uids, summary: 'Event')
    stub_request(:get, @calendar.url).to_return(body: feed(*uids, summary: summary))
    @service.import(@calendar.id)
  end

  def feed(*uids, summary: 'Event')
    calendar = Icalendar::Calendar.new
    uids.each do |uid|
      calendar.event do |event|
        event.uid = uid
        event.dtstart = Time.zone.local(2026, 11, 23, 10)
        event.dtend = Time.zone.local(2026, 11, 23, 11)
        event.summary = summary
      end
    end
    calendar.to_ical
  end

  def assert_preserved_with_warning
    warnings = []
    Rails.logger.stub(:warn, ->(message) { warnings << message }) { @service.import(@calendar.id) }
    assert_equal ['first'], @calendar.i_calendar_events.reload.pluck(:uid)
    assert_equal 1, warnings.size
    assert_includes warnings.first, @calendar.id.to_s
    assert_includes warnings.first, @calendar.url
  end
end
