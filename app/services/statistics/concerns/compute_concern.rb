# frozen_string_literal: true

# Provides methods to compute totals in statistics
module Statistics::Concerns::ComputeConcern
  extend ActiveSupport::Concern

  class_methods do
    def calcul_ca(invoice)
      return 0 unless invoice

      ca = 0
      # sum each items in the invoice (+ for invoices/- for refunds)
      invoice.invoice_items.each do |ii|
        next if ii.object_type == 'Subscription'

        ca = if invoice.is_a?(Avoir)
               ca - ii.amount_after_coupon
             else
               ca + ii.amount_after_coupon
             end
      end
      # divide the result by 100 to convert from centimes to monetary unit
      ca.zero? ? ca : ca / 100.0
    end

    def calcul_avoir_ca(invoice)
      ca = 0
      invoice.invoice_items.each do |ii|
        ca -= ii.amount_after_coupon
      end
      ca.zero? ? ca : ca / 100.0
    end
  end
end
