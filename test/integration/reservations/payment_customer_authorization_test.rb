# frozen_string_literal: true

require 'test_helper'

module Reservations; end

class Reservations::PaymentCustomerAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Warden.test_reset!
    @admin = users(:user1)
    @member = users(:user2)
    @manager = users(:user5)
    @manager.add_role(:manager)
    @other_manager = users(:user4)
    @other_manager.add_role(:manager)
    [@admin, @manager].each { |operator| operator.wallet.update!(amount: 100) }
    @space = Space.first
    [@admin, @member, @manager, @other_manager].each do |customer|
      price = @space.prices.find_or_initialize_by(group_id: customer.group_id, plan_id: customer.subscribed_plan&.id)
      price.update!(amount: 1500)
    end
    start_at = 9.days.from_now.change(hour: 12)
    availability = Availability.create!(available_type: 'space', start_at: start_at, end_at: start_at + 1.hour,
                                        spaces: [@space])
    @slot = availability.slots.create!(start_at: start_at, end_at: start_at + 1.hour)
    Slots::PlacesCacheService.refresh(@slot)
    login_as(@manager, scope: :user)
  end

  teardown do
    Warden.test_reset!
  end

  test 'manager cannot book and invoice an admin through local payment' do
    assert_customer_refused(@admin)
  end

  test 'manager cannot book and invoice another manager through local payment' do
    assert_customer_refused(@other_manager)
  end

  test 'manager can book for a member and themselves' do
    [@member, @manager].each { |customer| assert_booking_created(customer) }
  end

  test 'admin can still book for admins and managers' do
    login_as(@admin, scope: :user)
    [@admin, @other_manager].each { |customer| assert_booking_created(customer) }
  end

  %w[stripe/confirm_payment stripe/setup_subscription stripe/confirm_subscription stripe/update_card
     payzen/create_payment payzen/create_token payzen/check_cart payzen/confirm_payment payzen/confirm_payment_schedule].each do |endpoint|
    test "#{endpoint} refuses privileged customers before contacting the gateway" do
      [@admin, @other_manager].each do |customer|
        assert_no_difference ['Reservation.count', 'Invoice.count', 'PaymentSchedule.count'] do
          post "/api/#{endpoint}", params: { customer_id: customer.id, user_id: customer.id, cart_items: cart(customer) }.to_json,
                                   headers: default_headers
        end
        assert_response :forbidden
        assert_empty response.body
      end
    end
  end

  test 'nested and outer payment customers must both be authorized' do
    [{ customer_id: @admin.id, cart_items: cart(@member) }, { customer_id: @member.id, cart_items: cart(@admin) },
     { cart_items: cart(@other_manager) }].each do |payload|
      post '/api/payzen/create_payment', params: payload.to_json, headers: default_headers
      assert_response :forbidden
      assert_empty response.body
    end
  end

  test 'Stripe setup intent refuses another privileged customer' do
    get "/api/stripe/setup_intent/#{@admin.id}", headers: default_headers
    assert_response :forbidden
    assert_empty response.body
  end

  test 'payment schedule customer is authorized even without an explicit customer id' do
    schedule = PaymentSchedule.first
    schedule.update!(invoicing_profile: @admin.invoicing_profile)
    post '/api/payzen/update_token', params: { payment_schedule_id: schedule.id }.to_json, headers: default_headers
    assert_response :forbidden
    assert_empty response.body
  end

  test 'checkout authorizes supplied and existing cart customers before payment' do
    order = Order.create!(token: SecureRandom.hex, state: 'cart', operator_profile: @manager.invoicing_profile)
    assert_no_difference ['Reservation.count', 'Invoice.count', 'PaymentSchedule.count'] do
      post '/api/checkout/payment', params: { order_token: order.token, customer_id: @admin.id }.to_json, headers: default_headers
      assert_response :forbidden
      assert_nil order.reload.statistic_profile
      order.update!(statistic_profile: @other_manager.statistic_profile)
      post '/api/checkout/confirm_payment', params: { order_token: order.token }.to_json, headers: default_headers
      assert_response :forbidden
    end
  end

  private

  def cart(customer)
    { customer_id: customer.id, payment_method: 'local', items: [
      { reservation: { reservable_type: 'Space', reservable_id: @space.id,
                       slots_reservations_attributes: [{ slot_id: @slot.id, offered: false }] } }
    ] }
  end

  def assert_customer_refused(customer)
    assert_no_difference ['Reservation.count', 'Invoice.count', 'SlotsReservation.count', 'WalletTransaction.count', 'PaymentSchedule.count'] do
      post '/api/local_payment/confirm_payment', params: cart(customer).to_json, headers: default_headers
    end
    assert_response :forbidden
    assert_empty response.body
  end

  def assert_booking_created(customer)
    assert_difference ['Reservation.count', 'Invoice.count'], 1 do
      post '/api/local_payment/confirm_payment', params: cart(customer).to_json, headers: default_headers
      assert_response :created
    end
    assert_equal customer, Reservation.last.user
    assert_equal customer.invoicing_profile, Invoice.last.invoicing_profile
  end
end
