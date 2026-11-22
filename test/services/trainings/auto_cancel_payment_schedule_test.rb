# frozen_string_literal: true

require 'test_helper'

class Trainings::AutoCancelPaymentScheduleTest < ActiveSupport::TestCase
  setup do
    Setting.set('wallet_module', true)
    @customer = User.find(4)
    @customer.wallet.update!(amount: 155)
    @training = Training.find(4)
    @training.update!(auto_cancel: true, auto_cancel_threshold: 10, auto_cancel_deadline: 24)
    @last_transaction_id = WalletTransaction.maximum(:id) || 0
    @last_credit_note_id = Avoir.maximum(:id) || 0
  end

  test 'a scheduled reservation refunds each slot its share of the discounted aggregate item' do
    create_schedule
    footprint = @invoice.footprint
    assert_equal 4999, @reservation_item.amount_after_coupon

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    assert_equal [2500, 2499], refunds.pluck(:amount)
    assert_equal [2500, 2499], credit_notes.pluck(:total)
    assert_equal @reservation_item.amount_after_coupon, refunds.sum(:amount)
    assert_equal @reservation_item.amount_after_coupon, credit_notes.sum(:total)
    assert_equal 204.99, @customer.wallet.reload.amount
    assert @reservation.slots_reservations.reload.all?(&:canceled_at)
    assert_equal footprint, @invoice.reload.footprint
    assert @invoice.check_footprint
    assert @schedule.check_footprint
  end

  test 'an aggregate cent shared across three slots does not create zero-value refunds' do
    create_schedule(slot_count: 3, reservation_amount: 1, coupon_amount: nil)

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    assert_equal [1], refunds.pluck(:amount)
    assert_equal [1], credit_notes.pluck(:total)
    assert_equal 155.01, @customer.wallet.reload.amount
    assert @reservation.slots_reservations.reload.all?(&:canceled_at)
  end

  test 'fully discounted scheduled reservations do not create refunds' do
    create_schedule(coupon_amount: 6000)
    assert_equal 0, @reservation_item.amount_after_coupon

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    assert_empty refunds
    assert_empty credit_notes
    assert_equal 155, @customer.wallet.reload.amount
    assert @reservation.slots_reservations.reload.all?(&:canceled_at)
  end

  test 'scheduled reservations without an invoiced installment do not create refunds' do
    create_schedule(paid: false)
    assert_empty @reservation.invoice_items

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    assert_empty refunds
    assert_empty credit_notes
    assert_equal 155, @customer.wallet.reload.amount
    assert @reservation.slots_reservations.reload.all?(&:canceled_at)
  end

  test 'offered slots do not take a share of an aggregate paid item' do
    create_schedule(reservation_amount: 2500, coupon_amount: nil, offered_slots: 1)

    Trainings::AutoCancelService.auto_cancel_reservations(@training)

    assert_equal [2500], refunds.pluck(:amount)
    assert_equal [2500], credit_notes.pluck(:total)
    assert_equal 180, @customer.wallet.reload.amount
    assert @reservation.slots_reservations.reload.all?(&:canceled_at)
  end

  private

  def create_schedule(slot_count: 2, reservation_amount: 5000, coupon_amount: 1, paid: true, offered_slots: 0)
    create_reservation(slot_count, offered_slots)
    plan = plans(:plan_schedulable)
    plan.update!(amount: 12_000, group: @customer.group)
    subscription = Subscription.create!(plan: plan, statistic_profile: @customer.statistic_profile, start_at: Time.current)
    coupon = coupons(:cash2).tap { |record| record.update!(amount_off: coupon_amount) } if coupon_amount
    service = PaymentScheduleService.new
    @schedule = service.create([@reservation, subscription], plan.amount + reservation_amount, @customer,
                               coupon: coupon, operator: User.admins.first, payment_method: 'check')
    @schedule.save!
    return unless paid

    installment = @schedule.ordered_items.first
    assert service.generate_invoice(installment, payment_method: 'check')
    installment.update!(state: 'paid', payment_method: 'check')
    @invoice = installment.reload.invoice
    @reservation_item = @reservation.invoice_items.sole
  end

  def create_reservation(slot_count, offered_slots)
    availability = Availability.find(22)
    availability.update!(end_at: availability.start_at + slot_count.hours)
    slots = [availability.slots.first]
    (slot_count - 1).times do
      slots << availability.slots.create!(start_at: slots.last.end_at, end_at: slots.last.end_at + 1.hour)
    end
    @reservation = Reservation.create!(
      reservable: @training, statistic_profile: @customer.statistic_profile,
      slots_reservations_attributes: slots.each_with_index.map { |slot, index| { slot_id: slot.id, offered: index < offered_slots } }
    )
  end

  def refunds
    WalletTransaction.where('id > ?', @last_transaction_id).order(:id)
  end

  def credit_notes
    Avoir.where('id > ?', @last_credit_note_id).order(:id)
  end
end
