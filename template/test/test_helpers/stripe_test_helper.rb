# Stripe without the network: `gateway = connect_fake_stripe` connects the shop to a
# FakeStripeGateway that records what the app asked Stripe to do.
class FakeStripeGateway
  attr_reader :checkouts, :refunds, :webhooks, :deleted_webhooks
  attr_accessor :paid, :status, :error

  def initialize
    @checkouts, @refunds, @webhooks, @deleted_webhooks = [], [], [], []
    @paid, @status = false, "open"
  end

  def test_mode? = true
  def account_name = fail_or("Fake Shop LLC")

  def create_checkout(order, success_url:, cancel_url:)
    fail_or(nil)
    @checkouts << { order:, success_url:, cancel_url: }
    [ "cs_test_#{@checkouts.size}", "https://checkout.stripe.com/c/pay/cs_test_#{@checkouts.size}" ]
  end

  def checkout(id)
    fail_or({ paid:, payment_intent: ("pi_test_1" if paid), status: })
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
    Store.current.update!(stripe_secret_key: "sk_test_fake", stripe_account_name: "Fake Shop LLC", manual_payments: manual)
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
