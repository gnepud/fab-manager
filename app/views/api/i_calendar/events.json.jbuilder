# frozen_string_literal: true

events = @events.to_a
calendar = events.first&.i_calendar
background = icalendar_event_background_override(calendar) if calendar

json.array!(events) do |event|
  json.id event.uid
  json.className 'external-calendar-event'
  json.title calendar.text_hidden ? '' : event.summary
  json.start event.dtstart.iso8601
  json.end event.dtend.iso8601
  json.backgroundColor background if background
end
