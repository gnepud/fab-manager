# frozen_string_literal: true

require 'test_helper'
require 'stringio'

class InvoiceCurrencyTest < ActionDispatch::IntegrationTest
  setup do
    @settings = Rails.configuration.x.settings
    @original_currency = @settings.intl_currency
    @settings.intl_currency = 'EUR'
    @invoice = invoices('invoice_5')
  end

  teardown do
    @settings.intl_currency = @original_currency
  end

  test 'invoice PDFs show euros with the English Rails locale' do
    pdf = Pdf::Invoice.new(@invoice).render
    text = PDF::Reader.new(StringIO.new(pdf)).pages.map(&:text).join

    assert_includes text, '€15.00'
    assert_not_includes text, '$15.00'
  end

  test 'invoice notifications show euros with the English Rails locale' do
    user = @invoice.invoicing_profile.user
    login_as(user, scope: :user)
    notification_type = NotificationType.find_by!(name: 'notify_user_when_invoice_ready')
    notification = Notification.create!(receiver: user, attached_object: @invoice,
                                        notification_type_id: notification_type.id)

    patch "/api/notifications/#{notification.id}", headers: default_headers

    assert_response :success
    description = json_response(response.body).dig(:message, :description)
    assert_includes description, '€15.00'
    assert_not_includes description, '$15.00'
  end
end
