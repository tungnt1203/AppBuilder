# Every call to Stripe goes through here, with the shop's own secret key (Store#stripe). Buyers
# pay in the storefront with Stripe's Payment Element, confirming a PaymentIntent made here for
# their order; card numbers never reach the platform or the storefront.
#
# Tests replace StripeGateway.build with a fake (see test/test_helpers/stripe_test_helper.rb).
class StripeGateway
  Error = Class.new(StandardError)

  # Events the shop's webhook listens to.
  EVENTS = %w[ payment_intent.succeeded payment_intent.payment_failed charge.refunded ].freeze

  # Stripe amounts are in the currency's smallest unit; these have none below the whole unit,
  # while the shop keeps every amount in hundredths.
  ZERO_DECIMAL = %w[ VND JPY KRW ].freeze

  # How long a buyer has to pay before they're reminded (Order::ExpireUnpaidCardJob); the order
  # holds its stock until it's cancelled a day after it was placed.
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

  # The order's PaymentIntent, for its total as placed (with the tax worked out, when Stripe Tax
  # is on). Made once per order: asking again gets the same one. Returns { id:, client_secret: }.
  def create_payment_intent(order, tax_calculation: nil)
    intent = call do
      Stripe::PaymentIntent.create({
        amount: self.class.amount(order.total_cents, order.currency), currency: order.currency.downcase,
        automatic_payment_methods: { enabled: true },
        receipt_email: order.email,
        description: "#{order.shop.name} order #{order.name}",
        metadata: { order_id: order.id, order_number: order.number, shop: order.shop.uid, tax_calculation: }.compact,
        shipping: { name: order.shipping_name, phone: order.phone.presence, address: address(order) }.compact
      }, options.merge(idempotency_key: "order-#{order.shop.uid}-#{order.id}"))
    end
    { id: intent.id, client_secret: intent.client_secret }
  end

  # { paid:, status:, client_secret: } for a PaymentIntent.
  def payment_intent(id)
    intent = call { Stripe::PaymentIntent.retrieve(id, options) }
    { paid: intent.status == "succeeded", status: intent.status, client_secret: intent.client_secret }
  end

  # The tax Stripe Tax works out for the order's items and shipping at its address, on top of
  # its prices (the owner sets Stripe Tax up in their Stripe account). Returns { id:, tax_cents: }.
  def tax_calculation(order)
    shares = discounted_line_amounts(order)
    calculation = call do
      Stripe::Tax::Calculation.create({
        currency: order.currency.downcase,
        customer_details: { address: address(order), address_source: "shipping" },
        line_items: order.line_items.zip(shares).map { |item, cents|
          { amount: self.class.amount(cents, order.currency), quantity: item.quantity, reference: "line-#{item.id}", tax_behavior: "exclusive" }
        },
        shipping_cost: { amount: self.class.amount(order.shipping_cents, order.currency), tax_behavior: "exclusive" }
      }, options)
    end
    { id: calculation.id, tax_cents: self.class.cents(calculation.tax_amount_exclusive, order.currency) }
  end

  # Records a paid order's tax with Stripe Tax, for the owner's tax reports.
  def record_tax(calculation_id, reference)
    call { Stripe::Tax::Transaction.create_from_calculation({ calculation: calculation_id, reference: }, options) }
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
    def address(order)
      { line1: order.shipping_address1, line2: order.shipping_address2.presence, city: order.shipping_city,
        state: order.shipping_region.presence, postal_code: order.shipping_postal_code.presence, country: order.shipping_country }.compact
    end

    # Each line's price after its share of the order's discount, the last line taking what's left
    # over from rounding, so they add up to what the buyer pays for the items.
    def discounted_line_amounts(order)
      totals = order.line_items.map { |item| item.unit_price_cents * item.quantity }
      subtotal = totals.sum
      shares = totals.map { |total| subtotal.zero? ? 0 : (order.discount_cents * total / subtotal.to_f).floor }
      shares[-1] += order.discount_cents - shares.sum if shares.any?
      totals.zip(shares).map { |total, share| total - share }
    end

    def options
      { api_key: @secret_key }
    end

    def call
      yield
    rescue Stripe::StripeError => error
      raise Error, error.message.presence || error.class.name.demodulize
    end
end
