require "test_helper"

class StripePaymentsTest < ActiveSupport::TestCase
  setup { in_shop }

  include ActionMailer::TestHelper

  setup { @store = Store.current }

  test "buyers pay manually until Stripe is connected with both keys, then by card first" do
    assert_equal %w[ manual ], @store.payment_methods

    connect_fake_stripe
    Store.current.update!(stripe_publishable_key: nil)
    assert_equal %w[ manual ], Store.current.payment_methods, "the Payment Element needs the publishable key"
    Store.current.update!(stripe_publishable_key: "pk_test_fake")
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

  test "keys that aren't Stripe's, in two modes, or that Stripe refuses aren't saved" do
    assert_raises(StripeGateway::Error) { @store.connect_stripe!("pk_live_abc") }
    assert_raises(StripeGateway::Error) { @store.connect_stripe!("sk_live_abc", publishable_key: "pk_test_abc") }
    assert_not @store.update(stripe_secret_key: "sk_live_abc", stripe_publishable_key: "pk_test_abc")

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
      shipping_address1: "5 Elm St", shipping_city: "Austin", shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US")

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

  test "cancelling a card order already paid gives the money back" do
    gateway = connect_fake_stripe
    order = orders(:paid)
    order.update!(payment_method: "stripe", payment_reference: "pi_3")

    assert_enqueued_email_with OrderMailer, :cancelled, args: [ order ] do
      order.cancel!(reason: "Out of stock")
    end
    assert_equal [ "pi_3" ], gateway.refunds
    assert order.cancelled?
    assert_equal order.total_cents, order.refunded_cents
    assert_includes OrderMailer.cancelled(order).text_part.body.to_s, "refunded $20.00 to your card"
  end

  test "a cancel Stripe can't refund leaves the order paid" do
    gateway = connect_fake_stripe
    order = orders(:paid)
    order.update!(payment_method: "stripe", payment_reference: "pi_3")
    gateway.error = "No such payment"

    assert_raises(StripeGateway::Error) { order.cancel! }
    assert order.reload.paid?
  end

  test "a refund Stripe refuses leaves the order paid" do
    gateway = connect_fake_stripe
    order = orders(:paid)
    order.update!(payment_method: "stripe", payment_reference: "pi_2")
    gateway.error = "Charge already refunded"

    assert_raises(StripeGateway::Error) { order.refund! }
    assert order.reload.paid?
  end

  test "a card order is paid through one PaymentIntent, with Stripe Tax's tax when it's on" do
    gateway = connect_fake_stripe
    Store.current.update!(stripe_tax: true)
    gateway.tax_cents = 160
    order = orders(:pending).tap { |o| o.update!(payment_method: "stripe") }

    intent = order.card_payment!
    assert_equal [ "pi_test_1", "pi_test_1_secret_abc" ], intent.values_at(:id, :client_secret)
    assert_equal [ 160, 3060, "taxcalc_test_1" ], [ order.tax_cents, order.total_cents, order.stripe_tax_calculation_id ]
    assert_equal 3060, gateway.intents.sole[:amount_cents]
    assert_equal "pi_test_1", order.card_payment![:id], "asking again gets the same one"
    assert_equal 1, gateway.intents.size

    assert_nil order.sync_card_payment![:paid].presence
    assert order.reload.pending?
    gateway.status = "succeeded"
    order.sync_card_payment!
    assert order.reload.paid?
    assert_equal [ 3060, "pi_test_1" ], [ order.total_cents, order.payment_reference ]
    assert_equal [ [ "taxcalc_test_1", order.name ] ], gateway.tax_records
    assert_raises(Order::InvalidTransition) { order.card_payment! }
  end

  test "a buyer who didn't pay gets one reminder, and the order is cancelled after a day" do
    gateway = connect_fake_stripe
    order = orders(:pending).tap { |o| o.update!(payment_method: "stripe", stripe_payment_intent_id: "pi_old", created_at: 2.hours.ago) }

    gateway.status = "processing"
    assert_no_enqueued_emails { Order::ExpireUnpaidCardJob.perform_now }

    gateway.status = "requires_payment_method"
    assert_enqueued_email_with OrderMailer, :recovery, args: [ order ] do
      Order::ExpireUnpaidCardJob.perform_now
    end
    assert order.reload.pending?
    assert order.recovery_sent_at
    assert_no_enqueued_emails { Order::ExpireUnpaidCardJob.perform_now }

    order.update!(created_at: 25.hours.ago)
    Order::ExpireUnpaidCardJob.perform_now
    assert order.reload.cancelled?
  end

  test "the reminder links back to the order to pay" do
    order = orders(:pending)
    mail = OrderMailer.recovery(order)
    assert_equal [ order.email ], mail.to
    assert_includes mail.html_part.body.to_s, "/orders/#{order.token}"
    assert_includes mail.text_part.body.to_s, "Finish your order"
  end

  test "unpaid card orders are cancelled after a day, unless Stripe says they were paid" do
    gateway = connect_fake_stripe
    stale = orders(:pending).tap { |o| o.update!(payment_method: "stripe", stripe_payment_intent_id: "pi_old", created_at: 2.days.ago) }
    fresh = Order.create!(stale.attributes.except("id", "number", "token", "stripe_payment_intent_id", "created_at"))

    gateway.status = "requires_payment_method"
    Order::ExpireUnpaidCardJob.perform_now
    assert stale.reload.cancelled?
    assert fresh.reload.pending?

    fresh.update!(created_at: 2.days.ago, stripe_payment_intent_id: "pi_late")
    gateway.status = "succeeded"
    Order::ExpireUnpaidCardJob.perform_now
    assert fresh.reload.paid?
  end

  test "unpaid card orders don't need action" do
    orders(:pending).update!(payment_method: "stripe")
    assert_not_includes Order.needs_action, orders(:pending)
    assert_includes Order.needs_action, orders(:paid)
  end
end
