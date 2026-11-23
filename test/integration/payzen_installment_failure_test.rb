# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class PayzenInstallmentFailureTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include WebMock::API

  test 'a refused PayZen installment without a gateway transaction emails the admin' do
    Setting.set('payzen_endpoint', 'https://api.payzen.eu')
    Setting.set('payzen_username', 'test_user')
    Setting.set('payzen_password', 'test_password')
    schedule = payment_schedules('payment_schedule_13')
    item = schedule.ordered_items.second
    admin = User.admins.first
    item.update!(state: 'new', payment_method: nil, invoice_id: nil)
    assert_nil item.payment_gateway_object

    subscription = payzen_response('Subscription/Get', pastPaymentsNumber: 1, totalPaymentsNumber: 3)
    order = payzen_response('Order/Get', transactions: [{
                              operationType: 'DEBIT', status: 'UNPAID', detailedStatus: 'REFUSED',
                              transactionDetails: { paymentMethodDetails: { expectedCaptureDate: item.due_date.iso8601 } }
                            }])

    assert_no_difference 'Invoice.count' do
      PaymentScheduleItemWorker.new.perform(item.id)
    end
    assert_equal 'error', item.reload.state
    alert = admin.notifications.where(attached_object: item).joins(:notification_type)
                 .find_by!(notification_types: { name: 'notify_admin_payment_schedule_error' })
    email = nil
    CustomAsset.stub(:get_url, '/test-logo.png') do
      I18n.with_locale(:en) do
        assert_emails 1 do
          email = NotificationsMailer.send_mail_by(alert).deliver_now
        end
      end
    end
    assert_equal [admin.email], email.to
    assert_equal '[URGENT] Card debit error', email.subject
    assert_includes email.body.decoded, schedule.reference
    assert_includes email.body.decoded, 'consult the PayZen dashboard and contact the member'
  ensure
    remove_request_stub(subscription) if subscription
    remove_request_stub(order) if order
  end

  private

  def payzen_response(path, answer)
    stub_request(:post, "https://api.payzen.eu/api-payment/V4/#{path}/")
      .with(basic_auth: %w[test_user test_password])
      .to_return(status: 200, body: { status: 'SUCCESS', answer: answer }.to_json)
  end
end
