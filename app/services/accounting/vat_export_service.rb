# frozen_string_literal: false

# module definition
module Accounting; end

# Provides the routine to export the collected VAT data to a CSV file.
class Accounting::VatExportService
  include ActionView::Helpers::NumberHelper

  attr_reader :encoding, :format, :separator, :date_format, :columns, :decimal_separator

  def initialize(columns, encoding: 'UTF-8', format: 'CSV', separator: ';')
    @encoding = encoding
    @format = format
    @separator = separator
    @decimal_separator = '.'
    @date_format = '%Y-%m-%d'
    @columns = columns
    @vat_name = Setting.get('invoice_VAT-name')
  end

  def set_options(decimal_separator: ',', date_format: '%d/%m/%Y', label_max_length: nil, export_zeros: nil)
    @decimal_separator = decimal_separator
    @date_format = date_format
    # these unused parameters are required for compatibility with AccountingExportService
    @label_max_length = label_max_length
    @export_zeros = export_zeros
  end

  def export(start_date, end_date, file)
    # build CSV content
    content = header_row
    invoices = Invoice.where('created_at >= ? AND created_at <= ?', start_date, end_date).order('created_at ASC')
    vat_totals = compute_vat_totals(invoices)
    content << generate_rows(vat_totals, start_date, end_date)

    # write content to file
    File.open(file, "w:#{encoding}") { |f| f.puts content.encode(encoding, invalid: :replace, undef: :replace) }
  end

  private

  def header_row
    row = ''
    columns.each do |column|
      row << I18n.t("vat_export.#{column}", **{ NAME: @vat_name }) << separator
    end
    "#{row}\n"
  end

  def generate_rows(vat_totals, start_date, end_date)
    rows = ''

    vat_totals.each do |rate, total|
      next if rate.zero?

      rows += "#{row(
        start_date,
        end_date,
        rate,
        total
      )}\n"
    end

    rows
  end

  # Credit notes (Avoir) give back the VAT collected on the refunded items, so their VAT is deducted
  def compute_vat_totals(invoices)
    vat_totals = Hash.new(0)
    service = VatHistoryService.new
    invoices.each do |i|
      Rails.logger.info "processing invoice #{i.id}..." unless Rails.env.test?
      sign = i.is_a?(Avoir) ? -1 : 1
      service.invoice_vat(i).each_value do |group|
        vat_totals[group[:vat_rate]] += sign * group[:total_vat]
      end
    end
    vat_totals
  end

  # Generate a row of the export, filling the configured columns with the provided values
  def row(start_date, end_date, vat_rate, amount)
    row = ''
    columns.each do |column|
      case column
      when 'start_date'
        row << Time.zone.parse(start_date).strftime(date_format)
      when 'end_date'
        row << Time.zone.parse(end_date).strftime(date_format)
      when 'vat_rate'
        row << vat_rate.to_s
      when 'amount'
        row << format_number(amount / 100.0)
      else
        Rails.logger.warn "Unsupported column: #{column}"
      end
      row << separator
    end
    row
  end

  # Format the given number as a string, using the configured separator
  def format_number(num)
    number_to_currency(num, unit: '', separator: decimal_separator, delimiter: '', precision: 2)
  end
end
