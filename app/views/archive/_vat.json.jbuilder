# frozen_string_literal: true

json.amount do
  json.without_tax CurrencyFormatter.format((price - (price * vat_rate)) / 100.0)
  json.all_taxes_included CurrencyFormatter.format(price / 100.0)
  json.vat_rate vat_rate.positive? ? number_to_percentage(vat_rate * 100) : 'none'
end
