# frozen_string_literal: true

require 'test_helper'

module Events; end

class Events::DeletedChildBookingsTest < ActionDispatch::IntegrationTest
  setup do
    @parent = users(:user2)
    @admin = users(:user1)
    @child = @parent.children.create!(id: @parent.id, first_name: 'Child', last_name: 'Private', birthday: 8.years.ago)
    @event = Event.find(4)
    @event.update!(event_type: 'family')
    @reservation = Reservation.create!(
      statistic_profile: @parent.statistic_profile, reservable: @event, nb_reserve_places: 2,
      slots_reservations_attributes: [{ slot: @event.availability.slots.first, is_valid: true, is_confirm: true }]
    )
    @booking = @reservation.booking_users.create!(booked: @child, name: @child.full_name)
    @other_booking = @reservation.booking_users.create!(booked: @parent, name: @parent.profile.full_name)
    @original = reservation_state
  end

  teardown do
    Warden.test_reset!
  end

  test 'removing a child directly erases their booking identity without changing the reservation' do
    login_as(@parent, scope: :user)

    delete "/api/children/#{@child.id}", headers: default_headers

    assert_anonymized_booking
    assert_equal @parent.profile.full_name, @other_booking.reload[:name]
    assert_equal @parent, @other_booking.booked
  end

  test 'self account deletion anonymizes child bookings without canceling reservations' do
    login_as(@parent, scope: :user)

    delete "/api/members/#{@parent.id}", headers: default_headers

    assert_anonymized_booking
    assert_not User.exists?(@parent.id)
  end

  test 'admin account deletion anonymizes child bookings without canceling reservations' do
    login_as(@admin, scope: :user)

    delete "/api/members/#{@parent.id}", headers: default_headers

    assert_anonymized_booking
    assert_not User.exists?(@parent.id)
  end

  test 'removing a child with no bookings still succeeds' do
    child = @parent.children.create!(first_name: 'No', last_name: 'Bookings', birthday: 5.years.ago)
    login_as(@parent, scope: :user)

    assert_no_difference('BookingUser.count') do
      delete "/api/children/#{child.id}", headers: default_headers
    end

    assert_response :no_content
    assert_not Child.exists?(child.id)
    assert_equal @child.full_name, @booking.reload[:name]
  end

  test 'unauthorized child removal leaves booking identity untouched' do
    login_as(users(:user3), scope: :user)

    delete "/api/children/#{@child.id}", headers: default_headers

    assert_response :forbidden
    assert Child.exists?(@child.id)
    assert_equal @child.full_name, @booking.reload[:name]
    assert_equal @original, reservation_state
  end

  private

  def assert_anonymized_booking
    assert_response :no_content
    assert_not Child.exists?(@child.id)
    @booking.reload
    assert_nil @booking[:name]
    assert_nil @booking.booked_id
    assert_nil @booking.booked_type
    assert_nil @booking.booked
    assert_equal @original, reservation_state

    login_as(@admin, scope: :user)
    get '/api/reservations', params: { reservable_id: @event.id, reservable_type: 'Event', locale: 'fr' }, headers: default_headers

    assert_response :success
    booking = json_response(response.body).find { |reservation| reservation[:id] == @reservation.id }[:booking_users_attributes]
                                          .find { |user| user[:id] == @booking.id }
    assert_equal 'Utilisateur supprimé', booking[:name]
    assert_nil booking[:booked_id]
    assert_nil booking[:booked_type]
    assert_not booking.key?(:age)
  end

  def reservation_state
    {
      reservation: @reservation.reload.attributes,
      event: @event.reload.attributes,
      slots: @reservation.slots_reservations.map(&:attributes),
      places: @reservation.slots.map { |slot| slot.reload.places },
      tickets: @reservation.tickets.map(&:attributes),
      bookings: @reservation.booking_users.count,
      invoices: Invoice.count,
      invoice_items: InvoiceItem.count
    }
  end
end
