# frozen_string_literal: true

require 'test_helper'
require 'pay_zen/charge'

class PayZen::ChargeTest < ActiveSupport::TestCase
  include WebMock::API

  test 'create payment allows one retry after a card decline' do
    retry_count = nil
    stub = stub_request(:post, 'https://api.payzen.eu/api-payment/V4/Charge/CreatePayment')
           .with(basic_auth: %w[test_user test_password])
           .to_return do |request|
             retry_count = JSON.parse(request.body).dig('transactionOptions', 'cardOptions', 'retry')
             { body: '{"status":"SUCCESS"}' }
           end

    charge = PayZen::Charge.new(base_url: 'https://api.payzen.eu', username: 'test_user', password: 'test_password')
    charge.create_payment(amount: 1200, currency: 'EUR')

    assert_equal 1, retry_count
  ensure
    remove_request_stub(stub) if stub
  end
end
