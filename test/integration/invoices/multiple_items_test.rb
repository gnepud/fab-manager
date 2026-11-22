# frozen_string_literal: true

require 'test_helper'

module Invoices; end

class Invoices::MultipleItemsTest < ActionDispatch::IntegrationTest
  def setup
    @vlonchamp = User.find_by(username: 'vlonchamp')
    @admin = User.find_by(username: 'admin')
    login_as(@admin, scope: :user)
  end

  test 'invoice a cart with two prepaid packs' do
    pack50 = PrepaidPack.create!(priceable: Machine.first, group: @vlonchamp.group, amount: 5000, minutes: 600)
    pack20 = PrepaidPack.create!(priceable: Machine.first, group: @vlonchamp.group, amount: 2000, minutes: 120)

    post '/api/local_payment/confirm_payment', params: {
      customer_id: @vlonchamp.id,
      items: [
        { prepaid_pack: { id: pack50.id } },
        { prepaid_pack: { id: pack20.id } }
      ]
    }.to_json, headers: default_headers

    assert_equal 201, response.status, response.body

    invoice = Invoice.last
    assert_equal [5000, 2000], invoice.invoice_items.order(:id).map(&:amount)
    assert_equal 7000, invoice.total
  end
end
