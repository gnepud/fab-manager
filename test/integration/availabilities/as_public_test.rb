# frozen_string_literal: true

require 'test_helper'

class Availabilities::AsPublicTest < ActionDispatch::IntegrationTest
  test "[level == 'availability'] get public machines availabilities if machines module is active" do
    start_date = Time.current.to_date
    end_date = 7.days.from_now.to_date

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_machines}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each_with_index do |a, index|
      assert_not_nil a, "availability #{index} was unexpectedly nil"
      assert_equal 'machines', a[:available_type], "availability #{index} is not a machines availability"
      assert Time.zone.parse(a[:start]) > start_date, "availability #{index} starts before the requested period"
      assert Time.zone.parse(a[:end]) < end_date, "availability #{index} ends after the requested period"
    end
  end

  test "[level == 'slot'] get public machines availabilities if machines module is active" do
    start_date = Time.current.to_date
    end_date = start_date + 1.day

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_machines}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each do |a|
      assert_not_empty a[:machine_ids]
    end
  end

  test 'get anymore machines availabilities if machines module is inactive' do
    Setting.set('machines_module', false)
    start_date = Time.current.to_date
    end_date = 7.days.from_now.to_date

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_machines}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_empty availabilities
  end

  test 'get public trainings availabilities' do
    start_date = Time.current.to_date
    end_date = 7.days.from_now.to_date

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_trainings}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each_with_index do |a, index|
      assert_not_nil a, "availability #{index} was unexpectedly nil"
      assert_equal 'training', a[:available_type], "availability #{index} is not a training availability"
      assert Time.zone.parse(a[:start]) > start_date, "availability #{index} starts before the requested period"
      assert Time.zone.parse(a[:end]) < end_date, "availability #{index} ends after the requested period"
    end
  end

  test 'get public reserved training availability title' do
    login_as(users(:user7), scope: :user)
    availability = availabilities(:availability_12)
    availability.update!(start_at: 2.days.from_now.change(hour: 10), end_at: 2.days.from_now.change(hour: 14))
    availability.slots.first.update!(start_at: availability.start_at, end_at: availability.end_at)
    start_date = availability.start_at.to_date.beginning_of_week
    end_date = start_date + 7.days

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_trainings}"

    assert_equal 200, response.status
    reserved = json_response(response.body).find { |a| a[:id] == availability.id }
    assert_not_nil reserved, 'reserved training availability was not found'
    assert_equal "#{availability.title} - #{I18n.t('trainings.i_ve_reserved')}", reserved[:title]
  end

  test "[level == 'availability'] get public spaces availabilities" do
    start_date = Time.current.to_date
    end_date = 7.days.from_now.to_date

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_spaces}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each_with_index do |a, index|
      assert_not_nil a, "availability #{index} was unexpectedly nil"
      assert_equal 'space', a[:available_type], "availability #{index} is not a space availability"
      assert Time.zone.parse(a[:start]) > start_date, "availability #{index} starts before the requested period"
      assert Time.zone.parse(a[:end]) < end_date, "availability #{index} ends after the requested period"
    end
  end

  test "[level == 'slot'] get public spaces availabilities" do
    availability = Availability.find(21)
    start_at = 2.hours.from_now
    availability.update!(start_at: start_at, end_at: start_at + 1.hour)
    availability.slots.first.update!(start_at: start_at, end_at: start_at + 1.hour)

    start_date = Time.current.to_date
    end_date = start_date + 1.day

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_spaces}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each do |a|
      assert_not_nil a[:space_id]
    end
  end

  test 'get public spaces availabilities' do
    start_date = Time.current.to_date
    end_date = 7.days.from_now.to_date

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&#{all_spaces}"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each_with_index do |a, index|
      assert_not_nil a, "availability #{index} was unexpectedly nil"
      assert_equal 'space', a[:available_type], "availability #{index} is not a space availability"
      assert Time.zone.parse(a[:start]) > start_date, "availability #{index} starts before the requested period"
      assert Time.zone.parse(a[:end]) < end_date, "availability #{index} ends after the requested period"
    end
  end

  test 'get public events availabilities' do
    start_date = 8.days.from_now.to_date
    end_date = 16.days.from_now.to_date

    get "/api/availabilities/public?start=#{start_date}&end=#{end_date}&timezone=Europe%2FParis&evt=true"

    # Check response format & status
    assert_equal 200, response.status
    assert_match Mime[:json].to_s, response.content_type

    # Check the correct availabilities was returned
    availabilities = json_response(response.body)
    assert_not_empty availabilities, 'no availabilities were found'
    availabilities.each_with_index do |a, index|
      assert_not_nil a, "availability #{index} was unexpectedly nil"
      assert_equal 'event', a[:available_type], "availability #{index} is not a event availability"
      assert Time.zone.parse(a[:start]) > start_date, "availability #{index} starts before the requested period"
      assert Time.zone.parse(a[:end]) < end_date, "availability #{index} ends after the requested period"
    end
  end

  private

  def all_machines
    Machine.all.map { |m| "m%5B%5D=#{m.id}" }.join('&')
  end

  def all_trainings
    Training.all.map { |m| "t%5B%5D=#{m.id}" }.join('&')
  end

  def all_spaces
    Space.all.map { |m| "s%5B%5D=#{m.id}" }.join('&')
  end
end
