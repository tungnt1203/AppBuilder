require "test_helper"

class StorefrontApi::PaymentsTest < ActionDispatch::IntegrationTest
  ADDRESS = StorefrontApi::CheckoutsTest::ADDRESS

  setup do
    @api_key = api_key_for
    @gateway = ActsAsTenant.with_tenant(shops(:cats)) { connect_fake_stripe }
  end

  test "a card order is paid with the Payment Element, then shows paid" do
    order = place_card_order
    assert_equal [ "pending", true ], [ order["status"], order.dig("payment", "required") ]

    payment = api(:post, storefront_api_order_payment_path(order["token"]), headers: { "Idempotency-Key" => "pay-1" })["payment"]
    assert_response :created
    assert_equal [ "stripe", "pi_test_1_secret_abc", "pk_test_fake", 2900, true ], payment.values_at("provider", "client_secret", "publishable_key", "amount_cents", "test_mode")
    assert_equal payment, api(:post, storefront_api_order_payment_path(order["token"]), headers: { "Idempotency-Key" => "pay-1" })["payment"]
    assert_equal 1, @gateway.intents.size

    assert_equal "pending", api(:get, storefront_api_order_path(order["token"]))["order"]["status"]
    @gateway.status = "succeeded"
    assert_equal "paid", api(:get, storefront_api_order_path(order["token"]))["order"]["status"], "checked with Stripe when the buyer comes back"

    api :post, storefront_api_order_payment_path(order["token"])
    assert_response :unprocessable_entity
    assert_equal "payment_not_needed", response.parsed_body.dig("error", "code")
  end

  test "a preview pays in test mode only" do
    @api_key = api_key_for(kind: "preview")
    ActsAsTenant.with_tenant(shops(:cats)) { Store.current.update!(stripe_secret_key: "sk_live_fake", stripe_publishable_key: "pk_live_fake") }
    @gateway.define_singleton_method(:test_mode?) { false }
    order = place_card_order
    api :post, storefront_api_order_payment_path(order["token"])
    assert_equal "test_mode_unavailable", response.parsed_body.dig("error", "code")
  end

  test "what Stripe refuses comes back as payment_failed" do
    order = place_card_order
    @gateway.error = "Your account cannot currently make live charges."
    api :post, storefront_api_order_payment_path(order["token"])
    assert_response :bad_gateway
    assert_equal [ "payment_failed", "Your account cannot currently make live charges." ], response.parsed_body["error"].values_at("code", "message")
  end

  test "a storefront that calls too often is slowed down" do
    original = Rails.cache.method(:increment)
    Rails.cache.define_singleton_method(:increment) { |*| 601 }
    api :get, storefront_api_shop_path
    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body.dig("error", "code")
  ensure
    Rails.cache.define_singleton_method(:increment, original)
  end

  private
    def place_card_order
      cart = api(:post, storefront_api_carts_path)["cart"]["token"]
      api :post, storefront_api_cart_items_path(cart), params: { variant_id: variants(:tee_black_s).id }
      api(:post, storefront_api_checkouts_path, params: { cart_token: cart, payment_method: "stripe", **ADDRESS })["order"]
    end
end
