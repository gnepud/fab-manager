# frozen_string_literal: true

# Import all events from a given remote RFC 5545 iCalendar
class ICalendarImportService
  def import(i_calendar_id)
    require 'net/http'
    require 'uri'
    require 'icalendar'

    uids = []

    i_cal = ICalendar.find(i_calendar_id)
    cals = fetch_calendars(i_cal)
    return unless cals

    # create new events and update existings
    cals.each do |cal|
      cal.events.each do |evt|
        uids.push(evt.uid.to_s)
        ICalendarEvent.update_or_create_by(
          { uid: evt.uid.to_s, i_calendar_id: i_calendar_id },
          {
            dtstart: evt.dtstart,
            dtend: evt.dtend,
            summary: evt.summary,
            description: evt.description,
            i_calendar_id: i_calendar_id
          }
        )
      end
    end
    # remove deleted events
    ICalendarEvent.where(i_calendar_id: i_calendar_id).where.not(uid: uids).destroy_all
  end

  private

  def fetch_calendars(i_cal)
    response = Net::HTTP.get_response(URI.parse(i_cal.url))
    response.value
    calendars = Icalendar::Calendar.parse(response.body)
    raise ArgumentError, 'No VCALENDAR objects found' if calendars.empty?

    calendars
  rescue StandardError => e
    Rails.logger.warn("iCalendar import failed for calendar #{i_cal.id} (#{i_cal.url}): #{e.class}: #{e.message}")
    nil
  end
end
