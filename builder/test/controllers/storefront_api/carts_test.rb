require "test_helper"

class StorefrontApi::CartsTest < ActionDispatch::IntegrationTest
  setup do
    @api_key = api_key_for
    @token = api(:post, storefront_api_carts_path)["cart"]["token"]
    assert_response :created
  end

  test "adds, changes and takes out lines, answering with the whole cart" do
    cart = api(:post, storefront_api_cart_items_path(@token), params: { variant_id: variants(:tee_black_s).id, quantity: 2 })["cart"]
    assert_response :created
    assert_equal [ 2, 4800, "USD", 5200 ], cart.values_at("item_count", "subtotal_cents", "currency", "free_shipping_remaining_cents")
    line = cart["items"].sole
    assert_equal [ 2, 4800, "cat-mom-tee", "Black / S" ], [ line["quantity"], line["line_total_cents"], line.dig("product", "slug"), line.dig("variant", "title") ]

    cart = api(:post, storefront_api_cart_items_path(@token), params: { variant_id: variants(:tee_black_s).id })["cart"]
    assert_equal 3, cart["items"].sole["quantity"], "the same variant joins its line"

    cart = api(:patch, storefront_api_cart_item_path(@token, line["id"]), params: { quantity: 1 })["cart"]
    assert_equal 1, cart["item_count"]
    cart = api(:patch, storefront_api_cart_item_path(@token, line["id"]), params: { quantity: 0 })["cart"]
    assert_empty cart["items"]

    api :post, storefront_api_cart_items_path(@token), params: { variant_id: variants(:mug).id }
    mug = api(:get, storefront_api_cart_path(@token))["cart"]["items"].sole
    assert_empty api(:delete, storefront_api_cart_item_path(@token, mug["id"]))["cart"]["items"]
  end

  test "what can't be bought isn't added" do
    api :post, storefront_api_cart_items_path(@token), params: { variant_id: variants(:tee_white_s).id }
    assert_response :conflict
    assert_equal "unavailable", response.parsed_body.dig("error", "code")

    api :post, storefront_api_cart_items_path(@token), params: { variant_id: variants(:hoodie).id } # a draft
    assert_response :conflict
    api :post, storefront_api_cart_items_path(@token), params: {}
    assert_response :bad_request
  end

  test "a discount code applies when it can, and says why when it can't" do
    api :post, storefront_api_cart_items_path(@token), params: { variant_id: variants(:tee_black_s).id }
    body = api(:post, storefront_api_cart_discount_path(@token), params: { code: "fiveoff" })
    assert_response :unprocessable_entity
    assert_equal [ "below_minimum", "That code needs a bigger order" ], body["error"].values_at("code", "message")

    cart = api(:post, storefront_api_cart_discount_path(@token), params: { code: "welcome10" })["cart"]
    assert_equal({ "code" => "WELCOME10", "kind" => "percentage", "amount_cents" => 240 }, cart["discount"])
    assert_nil api(:delete, storefront_api_cart_discount_path(@token))["cart"]["discount"]
  end

  test "a cart and a variant of another shop aren't there" do
    api :get, storefront_api_cart_path(@token), key: api_key_for(shops(:dogs))
    assert_response :not_found

    dogs_cart = api(:post, storefront_api_carts_path, key: api_key_for(shops(:dogs)))["cart"]["token"]
    api :post, storefront_api_cart_items_path(dogs_cart), key: api_key_for(shops(:dogs)), params: { variant_id: variants(:mug).id }
    assert_response :not_found
  end
end
