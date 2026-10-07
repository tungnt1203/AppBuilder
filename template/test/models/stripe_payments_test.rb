require "test_helper"

class StripePaymentsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { @store = Store.current }

  test "buyers pay manually until Stripe is connected, then by card first" do
    assert_equal %w[ manual ], @store.payment_methods

    connect_fake_stripe
    assert_equal %w[ stripe manual ], Store.current.payment_methods

    Store.current.update!(manual_payments: false)
    assert_equal %w[ stripe ], Store.current.payment_methods
  end

  test "the secret key is stored encrypted" do
    connect_fake_stripe
    raw = Store.connection.select_value("SELECT stripe_secret_key FROM stores WHERE id = #{@store.id}")

    assert_not_includes raw, "sk_test_fake"
    assert_equal "sk_test_fake", Store.current.stripe_secret_key
  end

  test "connecting checks the key and registers the webhook only on a public https address" do
    gateway = FakeStripeGateway.new
    StripeGateway.define_singleton_method(:build) { |_key| gateway }

    @store.connect_stripe!(" sk_test_abc123 ", webhook_url: "http://localhost:3000/stripe/webhook")
    assert_equal [ "sk_test_abc123", "Fake Shop LLC" ], [ @store.stripe_secret_key, @store.stripe_account_name ]
    assert_empty gateway.webhooks

    @store.connect_stripe!("sk_live_abc123", webhook_url: "https://shop.example.com/stripe/webhook")
    assert_equal [ "https://shop.example.com/stripe/webhook" ], gateway.webhooks
    assert_equal [ "we_test_1", "whsec_test_secret" ], [ @store.stripe_webhook_id, @store.stripe_signing_secret ]

    @store.disconnect_stripe!
    assert_equal [ "we_test_1" ], gateway.deleted_webhooks
    assert_not @store.stripe_connected?
  end

  test "keys that aren't Stripe secret keys or that Stripe refuses aren't saved" do
    assert_raises(StripeGateway::Error) { @store.connect_stripe!("pk_live_abc") }

    gateway = FakeStripeGateway.new.tap { |fake| fake.error = "Invalid API Key provided" }
    StripeGateway.define_singleton_method(:build) { |_key| gateway }
    assert_raises(StripeGateway::Error) { @store.connect_stripe!("sk_live_wrong") }
    assert_not @store.reload.stripe_connected?
  end

  test "only public https addresses can receive webhooks" do
    assert Store.public_url?("https://shop.example.com/stripe/webhook")
    assert_not Store.public_url?("http://shop.example.com/stripe/webhook")
    assert_not Store.public_url?("https://myshop.localhost/stripe/webhook")
    assert_not Store.public_url?("https://192.168.1.4/stripe/webhook")
  end

  test "amounts are in the currency's smallest unit" do
    assert_equal 2500, StripeGateway.amount(2500, "USD")
    assert_equal 150_000, StripeGateway.amount(15_000_000, "VND")
  end

  test "a card checkout keeps the cart and sends no email until it's paid" do
    connect_fake_stripe
    cart = Cart.create!.tap { |c| c.add(variants(:mug)) }
    checkout = Checkout.new(cart:, payment_method: "stripe", email: "robin@example.com", shipping_name: "Robin",
      shipping_address1: "5 Elm St", shipping_city: "Austin", shipping_country: "US")

    assert_no_enqueued_emails { @order = checkout.place }
    assert @order.card? && @order.pending?
    assert_equal 1, cart.items.count

    assert_enqueued_emails(2) { assert @order.confirm_card_payment!(payment_intent: "pi_1") }
    assert @order.paid?
    assert_equal "pi_1", @order.payment_reference
    assert_equal 0, cart.items.count
    assert_not @order.confirm_card_payment!(payment_intent: "pi_1"), "confirming twice does nothing"
  end

  test "card orders are marked paid by Stripe, not by staff, and refunded through Stripe" do
    gateway = connect_fake_stripe
    order = orders(:pending)
    order.update!(payment_method: "stripe")
    assert_not order.can_mark_paid?

    order.confirm_card_payment!(payment_intent: "pi_9")
    order.refund!(reason: "Asked")
    assert_equal [ "pi_9" ], gateway.refunds
    assert order.refunded?
  end

  test "a refund Stripe refuses leaves the order paid" do
    gateway = connect_fake_stripe
    order = orders(:paid)
    order.update!(payment_method: "stripe", payment_reference: "pi_2")
    gateway.error = "Charge already refunded"

    assert_raises(StripeGateway::Error) { order.refund! }
    assert order.reload.paid?
  end

  test "unpaid card orders are cancelled after a day, unless Stripe says they were paid" do
    gateway = connect_fake_stripe
    stale = orders(:pending).tap { |o| o.update!(payment_method: "stripe", stripe_checkout_session_id: "cs_old", created_at: 2.days.ago) }
    fresh = Order.create!(stale.attributes.except("id", "number", "token", "stripe_checkout_session_id", "created_at"))

    gateway.status = "expired"
    Order::ExpireUnpaidCardJob.perform_now
    assert stale.reload.cancelled?
    assert fresh.reload.pending?

    fresh.update!(created_at: 2.days.ago, stripe_checkout_session_id: "cs_late")
    gateway.paid, gateway.status = true, "complete"
    Order::ExpireUnpaidCardJob.perform_now
    assert fresh.reload.paid?
  end

  test "unpaid card orders don't need action" do
    orders(:pending).update!(payment_method: "stripe")
    assert_not_includes Order.needs_action, orders(:pending)
    assert_includes Order.needs_action, orders(:paid)
  end
end
