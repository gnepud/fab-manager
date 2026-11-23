# frozen_string_literal: true

# Display colors for imported calendar events.
module ICalendarHelper
  MINIMUM_TEXT_CONTRAST = 4.5

  def icalendar_event_background_override(calendar)
    text = icalendar_luminance(calendar.text_color.presence || '#000')
    return 'white' unless text

    source = icalendar_luminance(calendar.color) if calendar.color.present?
    return if source && icalendar_contrast(text, source) >= MINIMUM_TEXT_CONTRAST

    icalendar_contrast(text, 1) >= MINIMUM_TEXT_CONTRAST ? 'white' : 'black'
  end

  private

  def icalendar_luminance(css_color)
    color = css_color.dup.paint
    return unless color.alpha == 1

    red, green, blue = color.rgb.to_a.first(3).map do |component|
      channel = component / 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  rescue Chroma::Errors::UnrecognizedColor
    nil
  end

  def icalendar_contrast(first, second)
    low, high = [first, second].minmax
    (high + 0.05) / (low + 0.05)
  end
end
