# frozen_string_literal: true

require 'test_helper'

class InvoicesTest < ActionDispatch::IntegrationTest
  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @admin = User.find_by(username: 'admin')
    login_as(@admin, scope: :user)
  end

  test 'admin list invoices' do
    post '/api/invoices/list', params: { query: {
      number: '',
      customer: '',
      date: nil,
      order_by: '-reference',
      page: 1,
      size: 20 # test db may have < 20 invoices
    } }.to_json, headers: default_headers

    # Check response format & status
    assert_equal 200, response.status, response.body
    assert_match Mime[:json].to_s, response.content_type

    # Check that we have all invoices
    invoices = json_response(response.body)
    assert_equal Invoice.count, invoices.size, 'some invoices are missing'

    # Check that invoices are ordered by reference
    first_invoice = Invoice.order(:reference).limit(1).first
    last_invoice = Invoice.order(reference: :desc).limit(1).first
    assert_equal last_invoice.reference, invoices.first[:reference]
    assert_equal first_invoice.reference, invoices.last[:reference]
  end

  test 'admin generates a refund' do
    date = Time.current.iso8601

    post '/api/invoices', params: { avoir: {
      avoir_date: date,
      payment_method: 'cash',
      description: 'Lorem ipsum',
      invoice_id: 4,
      invoice_items_ids: [4],
      subscription_to_expire: false
    } }.to_json, headers: default_headers

    # Check response format & status
    assert_equal 201, response.status, response.body
    assert_match Mime[:json].to_s, response.content_type

    # Check that the refund match
    refund = json_response(response.body)
    avoir = Avoir.find(refund[:id])

    assert_dates_equal date, refund[:avoir_date]
    assert_dates_equal date, refund[:date]
    assert_equal 'cash', refund[:payment_method]
    assert_equal false, refund[:has_avoir]
    assert_equal 4, refund[:invoice_id]
    assert_equal 4, refund[:items][0][:invoice_item_id]
    assert_match %r{^[0-9]+/A$}, refund[:reference]
    assert_equal 'Lorem ipsum', avoir.description

    # Check footprint
    assert avoir.check_footprint
  end

  test 'refunding an earlier subscription invoice expires only that subscription' do
    subscription = Subscription.find(2)
    renewal = subscription.dup
    renewal.save!
    renewal.update!(expiration_date: 2.months.from_now)
    invoice = subscription.original_invoice
    renewal_invoice = invoice.dup
    renewal_invoice.invoice_items.build(amount: invoice.total, object: renewal, main: true)
    renewal_invoice.save!

    assert_equal renewal, subscription.user.subscription

    post '/api/invoices', params: { avoir: {
      payment_method: 'cash',
      invoice_id: invoice.id,
      invoice_items_ids: invoice.invoice_items.ids,
      subscription_to_expire: true
    } }.to_json, headers: default_headers

    assert_equal 201, response.status, response.body
    assert subscription.reload.expired?, 'the refunded subscription should expire'
    assert_not renewal.reload.expired?, 'the renewal must remain active'
    assert_nil renewal.canceled_at
  end

  test 'refunding a scheduled subscription invoice expires the invoiced subscription' do
    customer = User.find_by!(username: 'jdupond')
    subscription = Subscription.create!(plan: plans(:plan_schedulable), statistic_profile: customer.statistic_profile)
    schedule = PaymentScheduleService.new.create([subscription], 113_600, customer, operator: @admin, payment_method: 'cash')
    schedule.save!
    installment = schedule.ordered_items.second
    PaymentScheduleService.new.generate_invoice(installment, payment_method: 'cash')
    invoice = installment.reload.invoice
    renewal = subscription.dup
    renewal.save!

    post '/api/invoices', params: { avoir: {
      payment_method: 'cash',
      invoice_id: invoice.id,
      invoice_items_ids: invoice.invoice_items.ids,
      subscription_to_expire: true
    } }.to_json, headers: default_headers

    assert_equal 201, response.status, response.body
    assert subscription.reload.expired?
    assert_not renewal.reload.expired?
  end

  test 'refund without a subscription does not expire the current subscription' do
    invoice = Invoice.find(4)
    subscription = Subscription.find(3)
    subscription.update!(expiration_date: 1.month.from_now)

    post '/api/invoices', params: { avoir: {
      payment_method: 'cash',
      invoice_id: invoice.id,
      invoice_items_ids: invoice.invoice_items.ids,
      subscription_to_expire: true
    } }.to_json, headers: default_headers

    assert_equal 201, response.status, response.body
    assert_not subscription.reload.expired?
  end
end
