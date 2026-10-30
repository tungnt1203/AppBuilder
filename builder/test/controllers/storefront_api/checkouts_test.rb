require "test_helper"

class StorefrontApi::CheckoutsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  ADDRESS = { email: "jo@example.com", shipping_name: "Pat Buyer", shipping_address1: "1 Main St", shipping_city: "Austin",
    shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }.freeze

  setup do
    @api_key = api_key_for
    @cart = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, storefront_api_cart_items_path(@cart), params: { variant_id: variants(:tee_black_s).id, quantity: 2 }
  end

  test "a buyer who typed their email and left gets one reminder of their cart, unless they ordered" do
    api :post, quote_storefront_api_checkouts_path, params: { cart_token: @cart, email: " Jo@Example.com ", shipping_country: "US" }
    cart = ActsAsTenant.with_tenant(shops(:cats)) { Cart.find_by!(token: @cart) }
    assert_equal "jo@example.com", cart.email

    travel 3.hours do
      assert_enqueued_emails(1) { Cart::RecoveryJob.perform_now }
      assert_no_enqueued_emails { Cart::RecoveryJob.perform_now }
    end
    mail = ActsAsTenant.with_tenant(shops(:cats)) { OrderMailer.cart_recovery(cart.reload).message }
    assert_equal [ "jo@example.com" ], mail.to
    assert_includes mail.text_part.body.to_s, "2 × Cat Mom Tee – Black / S"
    assert_includes mail.text_part.body.to_s, "/cart/restore/#{@cart}"

    ordered = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, storefront_api_cart_items_path(ordered), params: { variant_id: variants(:tee_black_s).id }
    api :post, quote_storefront_api_checkouts_path, params: { cart_token: ordered, email: "jo@example.com" }
    api :post, storefront_api_checkouts_path, params: ADDRESS.merge(cart_token: ordered, payment_method: "manual"), headers: { "Idempotency-Key" => "k1" }
    travel(3.hours) { Cart::RecoveryJob.perform_now }
    assert_nil ActsAsTenant.with_tenant(shops(:cats)) { Cart.find_by!(token: ordered).recovery_sent_at }, "it became an order"
  end

  test "the preview's carts are never reminded" do
    @api_key = api_key_for(kind: "preview")
    cart = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, quote_storefront_api_checkouts_path, params: { cart_token: cart, email: "jo@example.com" }
    assert_nil ActsAsTenant.with_tenant(shops(:cats)) { Cart.find_by!(token: cart).email }
  end

  test "quotes what the cart comes to, and what's missing" do
    body = api(:post, quote_storefront_api_checkouts_path, params: { cart_token: @cart, shipping_country: "US" })
    assert_response :success
    assert_equal [ 4800, 0, 700, true, 5500, [ "manual" ] ], body["checkout"].values_at("subtotal_cents", "discount_cents", "shipping_cents", "shipping_known", "total_cents", "payment_methods")
    assert_equal "can't be blank", body["problems"]["email"]
  end

  test "places a manual order, confirmed by email, and empties the cart" do
    assert_enqueued_emails 2 do
      body = api(:post, storefront_api_checkouts_path, params: { cart_token: @cart, **ADDRESS })
      assert_response :created
      order = body["order"]
      assert_equal [ "pending", false, "manual", 5500 ], [ order["status"], order["test"], order.dig("payment", "method"), order["total_cents"] ]
      assert_match "bank transfer", order.dig("payment", "instructions")
      assert_equal [ "Cat Mom Tee", "Black / S", 2 ], order["items"].sole.values_at("title", "variant_title", "quantity")

      assert_equal order["token"], api(:get, storefront_api_order_path(order["token"]))["order"]["token"]
      assert_equal [ "US", "United States" ], order["shipping_address"].values_at("country", "country_name")
    end
    assert_empty api(:get, storefront_api_cart_path(@cart))["cart"]["items"]
  end

  test "mistakes come back by field" do
    body = api(:post, storefront_api_checkouts_path, params: { cart_token: @cart, **ADDRESS, email: "nope", shipping_region: "Nowhere" })
    assert_response :unprocessable_entity
    assert_equal "invalid", body.dig("error", "code")
    assert_equal %w[ email shipping_region ], body.dig("error", "fields").keys.sort
  end

  test "the same Idempotency-Key places one order and answers the same again" do
    headers = { "Idempotency-Key" => "checkout-1" }
    first = api(:post, storefront_api_checkouts_path, params: { cart_token: @cart, **ADDRESS }, headers:)
    second = api(:post, storefront_api_checkouts_path, params: { cart_token: @cart, **ADDRESS }, headers:)
    assert_response :created
    assert_equal "true", response.headers["Idempotent-Replayed"]
    assert_equal first, second
    assert_equal 1, ActsAsTenant.with_tenant(shops(:cats)) { Order.where(email: "jo@example.com").count }

    api :post, storefront_api_checkouts_path, params: { cart_token: @cart, **ADDRESS, email: "other@example.com" }, headers: headers
    assert_response :unprocessable_entity
    assert_equal "idempotency_key_reused", response.parsed_body.dig("error", "code")
  end

  test "a preview places test orders, kept out of the shop's sales" do
    @api_key = api_key_for(kind: "preview")
    cart = api(:post, storefront_api_carts_path)["cart"]["token"]
    api :post, storefront_api_cart_items_path(cart), params: { variant_id: variants(:mug).id }
    order = api(:post, storefront_api_checkouts_path, params: { cart_token: cart, **ADDRESS })["order"]
    assert order["test"]
    ActsAsTenant.with_tenant(shops(:cats)) { assert_not Order.real.exists?(token: order["token"]) }
  end

  test "buyers review what they bought once it's on its way" do
    token = orders(:shipped).token
    body = api(:post, storefront_api_order_reviews_path(token), params: { author_name: "Lee", reviews: [ { product_slug: "cat-mom-tee", rating: 4, body: "Comfy" } ] })
    assert_response :created
    assert_equal [ 4, "Comfy", "Lee", "cat-mom-tee" ], body["reviews"].sole.values_at("rating", "body", "author_name", "product_slug")

    api :post, storefront_api_order_reviews_path(token), params: { reviews: [ { product_slug: "cat-mom-tee", rating: 5 } ] }
    assert_response :unprocessable_entity, "one review per product"
    api :post, storefront_api_order_reviews_path(orders(:paid).token), params: { reviews: [ { product_slug: "cat-mom-tee", rating: 5 } ] }
    assert_equal "nothing_to_review", response.parsed_body.dig("error", "code")
  end
end
