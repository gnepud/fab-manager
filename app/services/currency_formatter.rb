# frozen_string_literal: true

# Uses the configured currency without changing the locale's number format.
module CurrencyFormatter
  def self.format(amount)
    settings = Rails.configuration.x.settings
    options = { locale: settings.rails_locale }
    currency = settings.intl_currency.to_s.upcase.presence
    options[:unit] = TwitterCldr::Shared::Currencies.for_code(currency)&.fetch(:symbol) || currency if currency

    ActiveSupport::NumberHelper.number_to_currency(amount, options)
  end
end
