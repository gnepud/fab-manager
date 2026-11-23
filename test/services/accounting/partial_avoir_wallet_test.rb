# frozen_string_literal: true

require 'test_helper'

class Accounting::PartialAvoirWalletTest < ActiveSupport::TestCase
  setup do
    Setting.set('invoice_VAT-active', true)
    Setting.set('invoice_VAT-rate', '20')
    Setting.set('invoice_VAT-rate_Product', '20')
    travel 1.minute

    customer = User.find_by!(username: 'acamus')
    @invoice = Invoice.create!(
      total: 2700,
      wallet_amount: 2700,
      wallet_transaction: WalletTransaction.first,
      payment_method: '',
      invoicing_profile: customer.invoicing_profile,
      statistic_profile: customer.statistic_profile,
      operator_profile: User.find_by!(username: 'admin').invoicing_profile,
      invoice_items: [
        InvoiceItem.new(amount: 1200, description: '2 Nuts', object: OrderItem.first, main: true),
        InvoiceItem.new(amount: 1500, description: '3 Widgets', object: OrderItem.first, main: false)
      ]
    )
    @items = @invoice.invoice_items.order(:id).to_a
  end

  test 'successive partial wallet credit notes each balance their own taxable total' do
    original_attributes = @invoice.attributes
    assert_no_difference ['WalletTransaction.count', 'Wallet.sum(:amount)'] do
      assert_wallet_credit(create_avoir([@items.first.id]), 1200)
      assert_wallet_credit(create_avoir([@items.last.id]), 1500)
    end
    assert_equal original_attributes, @invoice.reload.attributes
  end

  test 'a full wallet credit note remains balanced' do
    assert_wallet_credit(create_avoir(@items.map(&:id)), 2700)
  end

  [500, 2000].each do |original_wallet_amount|
    test "wallet refund of a mixed payment uses the credit note total not the original #{original_wallet_amount} wallet share" do
      @invoice.update!(wallet_amount: original_wallet_amount, payment_method: 'card')
      original_means = [{ means: :wallet, amount: original_wallet_amount }, { means: :card, amount: 2700 - original_wallet_amount }]
      assert_equal original_means, @invoice.payment_means

      assert_wallet_credit(create_avoir([@items.first.id]), 1200)
      assert_equal original_means, @invoice.reload.payment_means
    end
  end

  test 'a wallet credit note does not require an original wallet payment' do
    @invoice.update!(wallet_amount: nil, wallet_transaction: nil, payment_method: 'card')
    assert_wallet_credit(create_avoir([@items.first.id]), 1200)
  end

  test 'wallet refund amount is calculated after the coupon discount' do
    @invoice.update!(coupon: coupons(:twentyp), total: 2160, wallet_amount: 2160)
    assert_wallet_credit(create_avoir([@items.first.id]), 960)
  end

  test 'empty and free line credit notes have no wallet amount to refund' do
    @items.first.update!(amount: 0)
    [[], [@items.first.id]].each do |ids|
      avoir = @invoice.reload.build_avoir(payment_method: 'wallet', invoice_items_ids: ids)
      assert_equal 0, avoir.total
      assert_equal 0, avoir.wallet_amount
    end
  end

  test 'other refund methods do not inherit an original wallet payment' do
    %w[cash card stripe cheque transfer none].each do |method|
      avoir = @invoice.build_avoir(payment_method: method, invoice_items_ids: [@items.first.id])
      assert_equal 0, avoir.wallet_amount
      assert_empty avoir.payment_means
    end
  end

  test 'an already refunded item still cannot be refunded twice' do
    create_avoir([@items.first.id])
    assert_raises(StandardError) { create_avoir([@items.first.id]) }
  end

  private

  def create_avoir(ids)
    avoir = @invoice.reload.build_avoir(payment_method: 'wallet', invoice_items_ids: ids)
    avoir.save!
    avoir.reload
  end

  def assert_wallet_credit(avoir, expected)
    Accounting::AccountingService.new.build_from_invoices(Invoice.where(id: avoir.id))
    lines = avoir.accounting_lines
    assert_equal expected, lines.where(line_type: 'payment').sum(:credit)
    assert_equal expected, lines.sum(:debit)
    assert_equal lines.sum(:debit), lines.sum(:credit)
    assert_equal expected / 6, lines.where(line_type: 'vat').sum(:debit)
    assert_equal expected, avoir.total
    assert_equal expected, avoir.wallet_amount
    assert_equal 0, avoir.amount_paid
    assert_equal [{ means: :wallet, amount: expected }], avoir.payment_means
    assert_equal 'wallet', lines.first.invoice_payment_method
    details = Invoices::PaymentDetailsService.build(avoir, avoir.total / 100.0)
    assert_includes details, I18n.t('invoices.by_wallet')
    assert_includes details, CurrencyFormatter.format(expected / 100.0)
  end
end
