require "test_helper"

# Stripe and Printify calling each shop's address (Webhooks::*): what lands on which order when
# shops share an account, and that each event is handled once.
class WebhooksTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @stripe = FakeStripeGateway.new
    @printify = FakePrintifyGateway.new
    [ shops(:cats), shops(:dogs) ].each do |shop|
      inside(shop) do
        connect_fake_stripe(@stripe) # the same owner's Stripe and Printify accounts, shared
        connect_fake_printify(@printify)
        Store.current.update!(stripe_webhook_secret: "whsec_#{shop.uid}", printify_webhook_secret: "pfy_#{shop.uid}")
      end
    end
    @order = inside(shops(:cats)) { orders(:pending).tap { |order| order.update!(payment_method: "stripe", stripe_payment_intent_id: "pi_cats_1") } }
  end

  def inside(shop, &) = ActsAsTenant.with_tenant(shop, &)

  test "a payment marks the shop's order paid once, however often Stripe sends it" do
    assert_enqueued_emails 2 do # the buyer's confirmation and the shop's notice
      2.times { stripe shops(:cats), "payment_intent.succeeded", id: "pi_cats_1", metadata: { order_id: @order.id, shop: "cats01" } }
    end

    assert_response :ok
    inside(shops(:cats)) do
      assert_equal [ "paid", "pi_cats_1" ], @order.reload.values_at(:status, :payment_reference)
      event = WebhookEvent.sole
      assert_equal [ "stripe", "evt_1", "payment_intent.succeeded", "processed", @order ], event.values_at(:provider, :event_id, :kind, :status, :order)
    end
  end

  test "a payment saved nowhere is found by the PaymentIntent's shop and order, never by an id alone" do
    inside(shops(:cats)) { @order.update!(stripe_payment_intent_id: nil) }

    stripe shops(:cats), "payment_intent.succeeded", id: "pi_other", metadata: { order_id: @order.id, shop: "dogs01" }
    assert inside(shops(:cats)) { @order.reload.pending? }, "another shop's order with the same id"

    stripe shops(:cats), "payment_intent.succeeded", id: "pi_lost", metadata: { order_id: @order.id, shop: "cats01" }, event_id: "evt_2"
    assert inside(shops(:cats)) { @order.reload.paid? }
  end

  test "another shop on the same Stripe account gets the event too and leaves the order alone" do
    stripe shops(:dogs), "payment_intent.succeeded", id: "pi_cats_1", metadata: { order_id: @order.id, shop: "cats01" }

    assert_response :ok
    assert inside(shops(:cats)) { @order.reload.pending? }
    assert_equal "ignored", inside(shops(:dogs)) { WebhookEvent.sole.status }

    stripe shops(:cats), "payment_intent.succeeded", id: "pi_cats_1", metadata: { order_id: @order.id, shop: "cats01" }
    assert inside(shops(:cats)) { @order.reload.paid? }, "the same event, at its own shop"
  end

  test "refunds made in Stripe, whole or in part, land on the order" do
    inside(shops(:cats)) { @order.confirm_card_payment!(payment_intent: "pi_cats_1") }

    stripe shops(:cats), "charge.refunded", id: "ch_1", payment_intent: "pi_cats_1", refunded: false, amount_refunded: 500, currency: "usd"
    inside(shops(:cats)) { assert_equal [ "paid", 500 ], @order.reload.values_at(:status, :refunded_cents) }

    stripe shops(:dogs), "charge.refunded", id: "ch_1", payment_intent: "pi_cats_1", refunded: true, event_id: "evt_2"
    assert inside(shops(:cats)) { @order.reload.paid? }

    stripe shops(:cats), "charge.refunded", id: "ch_1", payment_intent: "pi_cats_1", refunded: true, event_id: "evt_3"
    assert inside(shops(:cats)) { @order.reload.refunded? }
    assert_empty @stripe.refunds, "Stripe already refunded it"
  end

  test "a call Stripe didn't sign for this shop, for no shop, or for a shop without a webhook is refused" do
    body = event_json("payment_intent.succeeded", id: "pi_cats_1")
    post webhooks_stripe_path("cats01"), params: body, headers: { "Stripe-Signature" => stripe_signature(body, secret: "whsec_dogs01"), "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request

    post webhooks_stripe_path("nobody"), params: body, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :not_found

    inside(shops(:cats)) { Store.current.update!(stripe_webhook_secret: nil) }
    post webhooks_stripe_path("cats01"), params: body, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :not_found

    assert inside(shops(:cats)) { @order.reload.pending? && WebhookEvent.none? }
  end

  test "Printify's news ships the shop's order with what Printify itself says; the other shop on the account ignores it" do
    order = inside(shops(:cats)) { orders(:paid).tap { |paid| paid.update!(status: "in_production", printify_order_id: "pf-77") } }
    @printify.shipments = [ { "carrier" => "usps", "number" => "9400111", "url" => "https://tools.usps.com/t/9400111" } ]

    printify shops(:dogs), "order:shipment:created", "pf-77"
    assert_response :ok
    assert inside(shops(:cats)) { order.reload.in_production? }
    assert_equal "ignored", inside(shops(:dogs)) { WebhookEvent.sole.status }

    printify shops(:cats), "order:shipment:created", "pf-77"
    inside(shops(:cats)) do
      assert_equal [ "shipped", "9400111" ], order.reload.values_at(:status, :tracking_number)
      assert_equal [ "printify", "processed", order ], WebhookEvent.sole.values_at(:provider, :status, :order)
    end
  end

  test "an order Printify cancelled tells the shop's staff" do
    order = inside(shops(:cats)) { orders(:paid).tap { |paid| paid.update!(status: "in_production", printify_order_id: "pf-77") } }
    @printify.status = "canceled"

    printify shops(:cats), "order:updated", "pf-77"
    inside(shops(:cats)) { assert_match "Printify cancelled it", order.reload.fulfillment_error }
  end

  test "a forged Printify call, or one for a shop without webhooks, changes nothing" do
    post webhooks_printify_path("cats01"), params: printify_json("order:updated", "pf-77"), headers: { "Content-Type" => "application/json", "X-Pfy-Signature" => "sha256=forged" }
    assert_response :unauthorized

    inside(shops(:cats)) { Store.current.update!(printify_webhook_secret: nil) }
    printify shops(:cats), "order:updated", "pf-77"
    assert_response :not_found
  end

  test "an event that failed is recorded, and handled when it's sent again" do
    inside(shops(:cats)) do
      assert_raises(RuntimeError) { WebhookEvent.handle(provider: "stripe", event_id: "evt_9", kind: "charge.refunded", payload: {}) { raise "Stripe was down" } }
      assert_equal [ "failed", "RuntimeError: Stripe was down" ], WebhookEvent.sole.values_at(:status, :error)

      WebhookEvent.handle(provider: "stripe", event_id: "evt_9", kind: "charge.refunded", payload: {}) { @order }
      assert_equal [ "processed", nil, @order ], WebhookEvent.sole.values_at(:status, :error, :order)
    end
  end

  test "the admin registers each shop's own address with Stripe and Printify" do
    original = Rails.configuration.x.platform_url
    Rails.configuration.x.platform_url = "https://platform.example"
    in_shop_admin
    sign_in_as users(:cats_admin)

    post shop_admin_stripe_connection_path, params: { secret_key: "sk_test_new", publishable_key: "pk_test_new" }
    assert_equal [ "https://platform.example/webhooks/stripe/cats01" ], @stripe.webhooks

    patch shop_admin_printify_connection_path(register_webhooks: 1)
    assert_equal [ "https://platform.example/webhooks/printify/cats01" ], @printify.webhooks.pluck(:url).uniq
  ensure
    Rails.configuration.x.platform_url = original
  end

  private
    def stripe(shop, type, event_id: "evt_1", **object)
      body = event_json(type, event_id:, **object)
      post webhooks_stripe_path(shop.uid), params: body, headers: { "Stripe-Signature" => stripe_signature(body, secret: "whsec_#{shop.uid}"), "CONTENT_TYPE" => "application/json" }
    end

    def event_json(type, event_id: "evt_1", **object)
      { id: event_id, object: "event", type:, data: { object: object.merge(object: type.split(".").first) } }.to_json
    end

    def printify(shop, type, printify_order_id)
      body = printify_json(type, printify_order_id)
      signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "pfy_#{shop.uid}", body)}"
      post webhooks_printify_path(shop.uid), params: body, headers: { "Content-Type" => "application/json", "X-Pfy-Signature" => signature }
    end

    def printify_json(type, printify_order_id)
      { id: SecureRandom.uuid, type:, created_at: Time.current.iso8601, resource: { id: printify_order_id, type: "order", data: { shop_id: 4242 } } }.to_json
    end
end
