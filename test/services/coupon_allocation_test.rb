# frozen_string_literal: true

require 'test_helper'

class CouponAllocationTest < ActiveSupport::TestCase
  setup do
    Setting.set('wallet_module', true)
    @customer = User.find(4)
    @customer.wallet.update!(amount: 155)
    @training = Training.find(4)
    @training.update!(auto_cancel: true, auto_cancel_threshold: 3, auto_cancel_deadline: 24)
    @training.amount_by_group(@customer.group_id).update!(amount: 2500)
    availability = Availability.find(22)
    availability.update!(end_at: availability.end_at + 1.hour)
    slot = availability.slots.first
    second = availability.slots.create!(start_at: slot.end_at, end_at: slot.end_at + 1.hour)
    coupon = coupons(:cash2)
    coupon.update!(amount_off: 1001)
    CartService.new(User.admins.first).from_hash(ActionController::Parameters.new(
                                                   customer_id: @customer.id, coupon_code: coupon.code, payment_method: 'wallet',
                                                   items: [{ reservation: { reservable_id: @training.id, reservable_type: 'Training',
                                                                            slots_reservations_attributes: [
                                                                              { slot_id: slot.id }, { slot_id: second.id }
                                                                            ] } }]
                                                 )).build_and_save(nil, nil)
    @invoice = Invoice.only_invoice.order(:id).last
  end

  test 'odd-cent cash discount is allocated exactly across items' do
    assert_equal [2500, 2500], @invoice.invoice_items.map(&:amount)
    assert_equal 3999, @invoice.total
    assert_equal @invoice.total, @invoice.invoice_items.sum(&:amount_after_coupon)
    assert_equal [1999, 2000], @invoice.invoice_items.map(&:amount_after_coupon).sort
  end

  test 'auto cancellation refunds exactly the paid amount and creates balanced credit notes' do
    wallet_before = @customer.wallet.reload.amount
    credits_before = Avoir.count

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    refunded = ((@customer.wallet.reload.amount - wallet_before) * 100).round
    assert_equal @invoice.total, refunded
    assert_equal credits_before + 2, Avoir.count
    assert_equal [1999, 2000], Avoir.order(:id).last(2).map(&:total).sort
    assert_equal 155, @customer.wallet.amount
  end

  test 'full and partial manual credit notes use the same item allocations' do
    items = @invoice.invoice_items.order(:id).to_a
    full = @invoice.build_avoir(invoice_items_ids: items.map(&:id))
    partials = items.map { |item| @invoice.build_avoir(invoice_items_ids: [item.id]) }

    assert_equal @invoice.total, full.total
    assert_equal @invoice.total, partials.sum(&:total)
    assert_equal items.map(&:amount_after_coupon), partials.map(&:total)
    assert_equal full.total, full.invoice_items.sum(&:amount_after_coupon)
  end

  test 'allocation is stable across association ordering and coupon changes' do
    amounts = @invoice.invoice_items.to_h { |item| [item.id, item.amount_after_coupon] }
    @invoice.invoice_items.target.reverse!
    @invoice.coupon.update!(amount_off: 999, active: false)

    assert_equal(amounts, @invoice.invoice_items.to_h { |item| [item.id, item.amount_after_coupon] })
    assert_equal @invoice.total, @invoice.invoice_items.sum(&:amount_after_coupon)
  end

  test 'allocation and accounting leave existing invoice footprints intact' do
    elements = [@invoice, *@invoice.invoice_items]
    footprints = elements.map(&:footprint)
    assert @invoice.check_footprint

    Accounting::AccountingService.new.build_from_invoices(Invoice.where(id: @invoice.id))
    Pdf::Invoice.new(@invoice).render

    lines = @invoice.accounting_lines
    assert_equal lines.sum(:debit), lines.sum(:credit)
    assert_equal(@invoice.total, @invoice.invoice_items.sum { |item| item.net_amount + item.vat })
    assert_equal(footprints, elements.map { |element| element.reload.footprint })
    assert @invoice.check_footprint
  end

  test 'statistics use the allocated remainder when excluding subscriptions' do
    @invoice.invoice_items.load.first.object_type = 'Subscription'

    assert_equal 19.99, Statistics::FetcherService.calcul_ca(@invoice)
  end

  test 'credit note statistics preserve the allocated total and refund sign' do
    credit = @invoice.build_avoir(invoice_items_ids: @invoice.invoice_items.map(&:id))
    credit.invoice_items.first.object_type = 'Subscription'

    assert_equal(-19.99, Statistics::FetcherService.calcul_ca(credit))
    assert_equal(-39.99, Statistics::FetcherService.calcul_avoir_ca(credit))
  end
end
