# frozen_string_literal: true

# Provides methods for pay cart by Stripe
class Payments::StripeService
  require 'stripe/service'
  include Payments::PaymentConcern

  def payment(order, coupon_code, payment_id)
    amount = debit_amount(order, coupon_code)

    raise Cart::ZeroPriceError if amount.zero?

    # Create the PaymentIntent
    intent = Stripe::PaymentIntent.create(
      {
        payment_method: payment_id,
        amount: Stripe::Service.new.stripe_amount(amount),
        currency: Setting.get('stripe_currency'),
        confirmation_method: 'manual',
        confirm: true,
        customer: order.statistic_profile.user.payment_gateway_object.gateway_object_id
      }, { api_key: Setting.get('stripe_secret_key') }
    )

    if intent&.status == 'succeeded'
      o = payment_success(order, coupon_code, 'card', intent.id, intent.class.name)
      return { order: o }
    end

    if intent&.status == 'requires_action' && intent&.next_action&.type == 'use_stripe_sdk'
      { order: order, payment: { requires_action: true, payment_intent_client_secret: intent.client_secret,
                                 type: 'payment' } }
    end
  end

  def confirm_payment(order, coupon_code, payment_id)
    api_key = Setting.get('stripe_secret_key')
    intent = Stripe::PaymentIntent.retrieve(payment_id, { api_key: api_key })
    # the card was refused or failed authentication (3DS): keep the cart open so the customer can retry
    if intent.status == 'requires_payment_method'
      return { order: order, payment: { error: { statusText: payment_error_message(intent.last_payment_error) } } }
    end

    intent = Stripe::PaymentIntent.confirm(payment_id, {}, { api_key: api_key })
    if intent&.status == 'succeeded'
      o = payment_success(order, coupon_code, 'card', intent.id, intent.class.name)
      { order: o }
    else
      order.update(state: 'payment_failed')
      { order: order, payment: { error: { statusText: 'payment failed' } } }
    end
  end

  private

  def payment_error_message(error)
    return error.message if error&.type == 'card_error'

    I18n.t('errors.messages.gateway_authentication_failed')
  end
end
