# frozen_string_literal: true

require 'test_helper'

module Events; end

class Events::ZeroPlacesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_by(username: 'vlonchamp')
    login_as(@user, scope: :user)
    @event = Event.find(4)
    @event.update!(amount: 0, event_type: 'family')
    @event.event_price_categories.each { |category| category.update!(amount: 0) }
  end

  test 'refuses a free family event reservation without any places' do
    assert_no_difference ['Reservation.count', 'Invoice.count', 'WalletTransaction.count', 'BookingUser.count'] do
      book_event(0)
    end

    assert_response :unprocessable_entity
    assert_includes json_response(response.body)[:reservation], 'must be greater than 0'
  end

  test 'refuses a free family event reservation with zero category tickets' do
    assert_no_difference 'Reservation.count' do
      book_event(0, [{ event_price_category_id: @event.event_price_categories.first.id, booked: 0 }])
    end

    assert_response :unprocessable_entity
  end

  test 'accepts a free family event reservation with a normal place' do
    assert_difference 'Reservation.count' do
      book_event(1)
    end

    assert_response :created
    assert_equal 1, Reservation.last.total_booked_seats
  end

  test 'accepts a free family event reservation with only a category ticket' do
    assert_difference 'Reservation.count' do
      book_event(0, [{ event_price_category_id: @event.event_price_categories.first.id, booked: 1 }])
    end

    assert_response :created
    assert_equal 1, Reservation.last.total_booked_seats
  end

  private

  def book_event(places, tickets = [])
    post '/api/local_payment/confirm_payment', params: {
      customer_id: @user.id,
      items: [{
        reservation: {
          reservable_id: @event.id,
          reservable_type: 'Event',
          nb_reserve_places: places,
          slots_reservations_attributes: [{ slot_id: @event.availability.slots.first.id }],
          tickets_attributes: tickets
        }
      }]
    }.to_json, headers: default_headers
  end
end
