# Stripe without the network: `gateway = connect_fake_stripe` connects the shop to a
# FakeStripeGateway that records what the app asked Stripe to do. Its PaymentIntents are
# "requires_payment_method" until a test sets status = "succeeded" (or "processing").
class FakeStripeGateway
  attr_reader :intents, :refunds, :webhooks, :deleted_webhooks, :tax_records
  attr_accessor :status, :error, :tax_cents

  def initialize
    @intents, @refunds, @webhooks, @deleted_webhooks, @tax_records = [], [], [], [], []
    @status, @tax_cents = "requires_payment_method", 0
  end

  def test_mode? = true
  def account_name = fail_or("Fake Shop LLC")

  def create_payment_intent(order, tax_calculation: nil)
    fail_or(nil)
    @intents << { order:, amount_cents: order.total_cents, tax_calculation: }
    { id: "pi_test_#{@intents.size}", client_secret: "pi_test_#{@intents.size}_secret_abc" }
  end

  def payment_intent(id)
    fail_or({ paid: status == "succeeded", status:, client_secret: "#{id}_secret_abc" })
  end

  def tax_calculation(_order)
    fail_or({ id: "taxcalc_test_1", tax_cents: })
  end

  def record_tax(calculation_id, reference)
    @tax_records << [ calculation_id, reference ]
  end

  def refund(payment_intent)
    fail_or(@refunds << payment_intent)
  end

  def create_webhook(url)
    @webhooks << url
    [ "we_test_#{@webhooks.size}", "whsec_test_secret" ]
  end

  def delete_webhook(id)
    @deleted_webhooks << id
  end

  private
    def fail_or(value)
      raise StripeGateway::Error, error if error
      value
    end
end

module StripeTestHelper
  def connect_fake_stripe(gateway = FakeStripeGateway.new, manual: true)
    StripeGateway.define_singleton_method(:build) { |_key| gateway }
    Store.current.update!(stripe_secret_key: "sk_test_fake", stripe_publishable_key: "pk_test_fake", stripe_account_name: "Fake Shop LLC", manual_payments: manual)
    gateway
  end

  # A request body signed the way Stripe signs webhooks.
  def stripe_signature(payload, secret: "whsec_test_secret", time: Time.current)
    signature = Stripe::Webhook::Signature.compute_signature(time, payload, secret)
    Stripe::Webhook::Signature.generate_header(time, signature)
  end

  def after_teardown
    StripeGateway.define_singleton_method(:build) { |key| new(key) }
    super
  end
end

ActiveSupport.on_load(:active_support_test_case) { include StripeTestHelper }
