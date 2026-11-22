# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class Invoices::PaymentDetailsServiceTest < ActiveSupport::TestCase
  setup do
    @refund = Avoir.new(avoir_date: Date.new(2022, 6, 1))
  end

  test 'card credit notes include the online payment method in English and French' do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        @refund.payment_method = 'card'
        assert_equal refund_details('by_card_online_payment', 5), Invoices::PaymentDetailsService.build(@refund, 5)
      end
    end
  end

  test 'legacy stripe and other supported credit note methods keep their labels' do
    methods = { stripe: 'by_card_online_payment', cheque: 'by_cheque', transfer: 'by_transfer', cash: 'by_cash', wallet: 'by_wallet' }
    methods.each do |method, key|
      @refund.payment_method = method.to_s
      assert_equal refund_details(key, 5), Invoices::PaymentDetailsService.build(@refund, 5)
    end
  end

  test 'zero amount card credit notes still include the method' do
    @refund.payment_method = 'card'
    assert_equal refund_details('by_card_online_payment', 0), Invoices::PaymentDetailsService.build(@refund, 0)
  end

  test 'credit notes with no refund keep their existing description' do
    @refund.payment_method = 'none'
    expected = "#{I18n.t('invoices.no_refund')} #{I18n.t('invoices.for_an_amount_of_AMOUNT', AMOUNT: CurrencyFormatter.format(5))}"
    assert_equal expected, Invoices::PaymentDetailsService.build(@refund, 5)
  end

  test 'missing or unknown credit note methods still log an error' do
    [nil, 'unknown'].each do |method|
      @refund.payment_method = method
      errors = []
      Rails.logger.stub(:error, ->(message) { errors << message }) do
        assert_equal refund_details('', 5), Invoices::PaymentDetailsService.build(@refund, 5)
      end
      assert_equal 1, errors.size
      assert_match(/specified refunding method .* is unknown/, errors.first)
    end
  end

  private

  def refund_details(method_key, total)
    method = method_key.empty? ? '' : I18n.t("invoices.#{method_key}")
    "#{I18n.t('invoices.refund_on_DATE', DATE: I18n.l(@refund.avoir_date.to_date))} #{method} " \
      "#{I18n.t('invoices.for_an_amount_of_AMOUNT', AMOUNT: CurrencyFormatter.format(total))}"
  end
end
