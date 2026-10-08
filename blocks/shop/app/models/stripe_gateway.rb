# Every call to Stripe goes through here, with the shop's own secret key (Store#stripe). Buyers
# pay on Stripe Checkout; the shop never sees card numbers. Don't change this file for a
# feature: payments are part of the template, tested as they are.
#
# Tests replace StripeGateway.build with a fake (see test/test_helpers/stripe_test_helper.rb).
class StripeGateway
  Error = Class.new(StandardError)

  # Events the shop's webhook listens to (see StripeWebhooksController).
  EVENTS = %w[
    checkout.session.completed checkout.session.async_payment_succeeded
    checkout.session.async_payment_failed checkout.session.expired charge.refunded
  ].freeze

  # Stripe amounts are in the currency's smallest unit; these have none below the whole unit,
  # while the shop keeps every amount in hundredths.
  ZERO_DECIMAL = %w[ VND JPY KRW ].freeze

  # How long a buyer has to pay on Stripe (Stripe's shortest is 30 minutes). Until then the
  # order holds its stock; Order::ExpireUnpaidCardJob gives it back after.
  CHECKOUT_EXPIRY = 1.hour

  def self.build(secret_key)
    new(secret_key)
  end

  def self.amount(cents, currency)
    ZERO_DECIMAL.include?(currency.to_s.upcase) ? cents / 100 : cents
  end

  # Back from Stripe's amount to the shop's hundredths.
  def self.cents(amount, currency)
    ZERO_DECIMAL.include?(currency.to_s.upcase) ? amount.to_i * 100 : amount.to_i
  end

  def initialize(secret_key)
    @secret_key = secret_key
  end

  def test_mode?
    @secret_key.to_s.match?(/\A(sk|rk)_test_/)
  end

  # The account's display name; raises Error when the key doesn't work.
  def account_name
    account = call { Stripe::Account.retrieve(nil, options) }
    account.settings&.dashboard&.display_name.presence || account.business_profile&.name.presence || account.email.presence || account.id
  end

  # A Checkout Session for the order's items, discount and shipping, as they were when it was
  # placed, open for CHECKOUT_EXPIRY. With tax: true, Stripe Tax works out the tax on top (the
  # owner sets it up in their Stripe account). Returns [session id, url to send the buyer to].
  def create_checkout(order, success_url:, cancel_url:, tax: false)
    currency = order.currency.downcase
    session = call do
      Stripe::Checkout::Session.create({
        mode: "payment",
        expires_at: CHECKOUT_EXPIRY.from_now.to_i,
        automatic_tax: { enabled: tax },
        discounts: discounts_for(order),
        customer_email: order.email,
        client_reference_id: order.id.to_s,
        metadata: { order_id: order.id, order_number: order.number },
        payment_intent_data: { description: "Order #{order.name}", metadata: { order_id: order.id, order_number: order.number } },
        line_items: order.line_items.map { |item|
          { quantity: item.quantity,
            price_data: { currency:, unit_amount: self.class.amount(item.unit_price_cents, order.currency),
              product_data: { name: [ item.product_title, item.variant_title ].compact_blank.join(" – ").truncate(250) } } }
        },
        shipping_options: [ { shipping_rate_data: { type: "fixed_amount", display_name: order.shipping_cents.zero? ? "Free shipping" : "Shipping",
          fixed_amount: { amount: self.class.amount(order.shipping_cents, order.currency), currency: } } } ],
        success_url:, cancel_url:
      }, options)
    end
    [ session.id, session.url ]
  end

  # { paid:, payment_intent:, status:, tax_cents: } for a Checkout Session.
  def checkout(session_id)
    session = call { Stripe::Checkout::Session.retrieve(session_id, options) }
    { paid: session.payment_status.in?(%w[ paid no_payment_required ]), payment_intent: payment_intent_id(session.payment_intent),
      status: session.status, tax_cents: self.class.tax_cents(session) }
  end

  # The tax Stripe added to a Checkout Session, in the shop's hundredths.
  def self.tax_cents(session)
    cents(session.total_details&.amount_tax.to_i, session.currency)
  end

  def refund(payment_intent)
    call { Stripe::Refund.create({ payment_intent: }, options) }
  end

  # Registers the shop's webhook endpoint. Returns [id, signing secret].
  def create_webhook(url)
    endpoint = call do
      Stripe::WebhookEndpoint.create({ url:, enabled_events: EVENTS, description: "#{Rails.configuration.x.app_name} shop" }, options)
    end
    [ endpoint.id, endpoint.secret ]
  end

  def delete_webhook(id)
    call { Stripe::WebhookEndpoint.delete(id, {}, options) }
  rescue Error
    nil # already gone, or the key no longer works: nothing left to clean up
  end

  # The verified event, or raises Error when the signature doesn't match.
  def self.event(payload, signature, secret)
    Stripe::Webhook.construct_event(payload, signature.to_s, secret.to_s)
  rescue JSON::ParserError, Stripe::SignatureVerificationError => error
    raise Error, error.message
  end

  private
    # The order's discount as a one-off Stripe coupon for exactly the amount it took off.
    def discounts_for(order)
      return [] unless order.discount_cents.positive?

      coupon = call do
        Stripe::Coupon.create({ amount_off: self.class.amount(order.discount_cents, order.currency), currency: order.currency.downcase,
          duration: "once", max_redemptions: 1, name: order.discount_code.presence || "Discount" }, options)
      end
      [ { coupon: coupon.id } ]
    end

    def options
      { api_key: @secret_key }
    end

    def call
      yield
    rescue Stripe::StripeError => error
      raise Error, error.message.presence || error.class.name.demodulize
    end

    def payment_intent_id(value)
      value.is_a?(String) ? value : value&.id
    end
end
