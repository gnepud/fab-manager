# frozen_string_literal: true

require 'test_helper'

class PaymentScheduleServiceTest < ActiveSupport::TestCase
  test 'forever coupon remains applied to installments after selling out' do
    customer = users(:user2)
    operator = User.find_by(username: 'admin')
    plan = plans(:plan_schedulable)
    plan.update!(amount: 12_000)
    coupon = coupons(:two)
    coupon.update!(percent_off: 10, max_usages: 2)
    subscription = Subscription.create!(plan: plan, statistic_profile: customer.statistic_profile, start_at: Time.current)
    service = PaymentScheduleService.new
    schedule = service.create([subscription], plan.amount, customer, coupon: coupon, operator: operator, payment_method: 'check')
    schedule.save!

    schedule.ordered_items.first(3).each_with_index do |item, index|
      assert_equal 900, item.amount
      assert service.generate_invoice(item, payment_method: 'check')
      item.update!(state: 'paid', payment_method: 'check')
      assert_equal item.amount, item.reload.invoice.total, "installment #{index + 1} lost its discount"
    end

    assert_equal 'sold_out', coupon.status(customer.id)
    assert_equal 1000, CouponService.new.apply(1000, coupon, customer.id)
    assert_raises(InvalidCouponError) { CouponService.new.validate(coupon.code, customer.id) }
  end
end
