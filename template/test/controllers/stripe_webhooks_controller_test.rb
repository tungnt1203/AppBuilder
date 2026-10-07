require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @gateway = connect_fake_stripe
    Store.current.update!(stripe_webhook_secret: "whsec_test_secret", stripe_webhook_id: "we_1")
    @order = orders(:pending).tap { |order| order.update!(payment_method: "stripe", stripe_checkout_session_id: "cs_live_1") }
  end

  test "a completed checkout marks the order paid" do
    deliver "checkout.session.completed", id: "cs_live_1", payment_status: "paid", payment_intent: "pi_7", metadata: { order_id: @order.id }

    assert_response :ok
    assert @order.reload.paid?
    assert_equal "pi_7", @order.payment_reference
  end

  test "a checkout still waiting for a bank payment stays pending" do
    deliver "checkout.session.completed", id: "cs_live_1", payment_status: "unpaid", payment_intent: "pi_7", metadata: {}
    assert @order.reload.pending?
  end

  test "an expired checkout cancels the order" do
    deliver "checkout.session.expired", id: "cs_live_1", payment_status: "unpaid", metadata: {}
    assert @order.reload.cancelled?
  end

  test "a refund made in Stripe marks the order refunded without refunding again" do
    @order.confirm_card_payment!(payment_intent: "pi_7")
    deliver "charge.refunded", id: "ch_1", payment_intent: "pi_7", refunded: true

    assert @order.reload.refunded?
    assert_empty @gateway.refunds
  end

  test "requests Stripe didn't sign are refused" do
    payload = event_json("checkout.session.completed", id: "cs_live_1", payment_status: "paid", payment_intent: "pi_7")
    post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => stripe_signature(payload, secret: "whsec_other"), "CONTENT_TYPE" => "application/json" }

    assert_response :bad_request
    assert @order.reload.pending?
  end

  test "without a webhook secret there's nothing to receive" do
    Store.current.update!(stripe_webhook_secret: nil)
    post stripe_webhook_path, params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :not_found
  end

  private
    def deliver(type, **object)
      payload = event_json(type, **object)
      post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => stripe_signature(payload), "CONTENT_TYPE" => "application/json" }
    end

    def event_json(type, **object)
      { id: "evt_1", object: "event", type:, data: { object: object.merge(object: type.split(".").first(2).join(".")) } }.to_json
    end
end
