# frozen_string_literal: true

require 'test_helper'

module Invoices; end

class Invoices::VATTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.find_by(username: 'admin')
    login_as(@admin, scope: :user)
  end

  test 'renamed VAT' do
    Setting.set('invoice_VAT-active', true)
    Setting.set('invoice_VAT-name', 'TVQ+TPS')

    invoice = purchase_subscription_invoice
    assert_invoice_pdf invoice do |lines|
      vat_line = I18n.t('invoices.including_VAT_RATE',
                        **{ RATE: Setting.get('invoice_VAT-rate'),
                            AMOUNT: CurrencyFormatter.format(invoice.total / 100.00),
                            NAME: 'TVQ+TPS' })
      assert(lines.any? { |l| /#{Regexp.escape(vat_line)}/.match(l) })
    end
  end

  test 'credit note does not add VAT to an invoice issued without VAT' do
    travel_to(2.days.ago) { Setting.set('invoice_VAT-active', false) }
    invoice = travel_to(1.day.ago) { purchase_subscription_invoice }
    Setting.set('invoice_VAT-active', true)
    Setting.set('invoice_VAT-rate', 20)
    credit_note = create_credit_note(invoice)

    assert_includes invoice_pdf_text(invoice), I18n.t('invoices.total_amount')
    assert_includes invoice_pdf_text(credit_note), I18n.t('invoices.total_amount')
  end

  test 'credit note preserves the VAT charged before a rate change' do
    travel_to(2.days.ago) do
      Setting.set('invoice_VAT-active', true)
      Setting.set('invoice_VAT-rate_Subscription', 10)
    end
    invoice = travel_to(1.day.ago) { purchase_subscription_invoice }
    Setting.set('invoice_VAT-rate_Subscription', 20)
    credit_note = create_credit_note(invoice)

    vat_line = I18n.t(
      'invoices.including_VAT_RATE',
      RATE: 10.0, AMOUNT: CurrencyFormatter.format(invoice.total / 100.00), NAME: Setting.get('invoice_VAT-name')
    )
    assert_includes invoice_pdf_text(invoice), vat_line
    assert_includes invoice_pdf_text(credit_note), vat_line
    assert_equal invoice.main_item.vat, credit_note.main_item.vat
  end

  private

  def purchase_subscription_invoice
    user = User.find_by(username: 'vlonchamp')
    plan = Plan.find(5)

    post '/api/local_payment/confirm_payment', params: {
      customer_id: user.id,
      items: [
        {
          subscription: {
            plan_id: plan.id
          }
        }
      ]
    }.to_json, headers: default_headers

    assert_equal 201, response.status, response.body
    assert_match Mime[:json].to_s, response.content_type

    Invoice.last
  end

  def create_credit_note(invoice)
    post '/api/invoices', params: {
      avoir: {
        invoice_id: invoice.id,
        invoice_items_ids: invoice.invoice_items.ids,
        payment_method: 'cash'
      }
    }.to_json, headers: default_headers
    assert_equal 201, response.status, response.body

    Avoir.find(json_response(response.body).fetch(:id))
  end

  def invoice_pdf_text(invoice)
    pdf = Pdf::Invoice.new(invoice).render
    PDF::Reader.new(StringIO.new(pdf)).pages.first.text
  end
end
