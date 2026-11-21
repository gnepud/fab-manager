# frozen_string_literal: true

require 'test_helper'

class Accounting::VatExportServiceTest < ActiveSupport::TestCase
  setup do
    @admin = User.find_by(username: 'admin')
    @acamus = User.find_by(username: 'acamus')
    Setting.set('invoice_VAT-active', true)
    Setting.set('invoice_VAT-rate', '20')
    # VatHistoryService compares dates to the second: keep the documents clear of the settings change
    travel 1.minute
    @file = Rails.root.join('tmp', "vat_export_test_#{SecureRandom.hex(4)}.csv")
  end

  teardown do
    FileUtils.rm_f(@file)
  end

  test 'credit notes VAT is deducted from the collected VAT' do
    sample_reservation_invoice(@acamus, @admin)
    refunded = sample_reservation_invoice(@acamus, @admin)
    refunded.build_avoir(payment_method: 'cash', invoice_items_ids: refunded.invoice_items.map(&:id)).save!

    service = Accounting::VatExportService.new(%w[vat_rate amount])
    service.set_options
    service.export(1.hour.ago.iso8601, 1.hour.from_now.iso8601, @file)

    rows = File.readlines(@file, chomp: true).drop(1).map { |line| line.split(';') }
    # 1000 TTC at 20% => 1,67 of VAT; two invoices minus one credit note => 1,67
    assert_equal [['20.0', '1,67']], rows
  end
end
