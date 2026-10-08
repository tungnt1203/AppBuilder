require "test_helper"

class Agent::StorefrontTest < ActionDispatch::IntegrationTest
  setup do
    @key = Store.current.generate_agent_key!("storefront")
    @headers = { "Authorization" => "Bearer #{@key}", "X-Agent-Session" => "conversation-1" }
  end

  test "needs the storefront key; the merchant key doesn't open it" do
    get agent_storefront_products_path
    assert_response :unauthorized

    merchant_key = Store.current.generate_agent_key!("merchant")
    get agent_storefront_products_path, headers: { "Authorization" => "Bearer #{merchant_key}" }
    assert_response :unauthorized
  end

  test "searches the active catalog: a product with options is one result" do
    get agent_storefront_products_path(query: "tee"), headers: @headers
    product = response.parsed_body["products"].sole

    assert_equal "product-#{products(:tee).slug}", product["product_id"]
    assert_equal 24.0, product["price"]
    assert_equal({ "Color" => %w[ Black White ], "Size" => %w[ S M ] }, product["options"])

    get agent_storefront_products_path(query: "hoodie"), headers: @headers
    assert_empty response.parsed_body["products"], "drafts aren't for sale"
  end

  test "details list a family's variants with their own ids, prices and stock" do
    get agent_storefront_product_path("product-#{products(:tee).slug}"), headers: @headers
    variants = response.parsed_body["variants"]

    white_s = variants.find { |variant| variant["option_values"] == { "Color" => "White", "Size" => "S" } }
    assert_equal false, white_s["in_stock"]
    assert_equal "product-#{products(:tee).slug}", white_s["variant_of"]

    get agent_storefront_product_path("product-nope"), headers: @headers
    assert_response :not_found
  end

  test "fills the conversation's cart, refuses what can't be bought, and hands it to the buyer's browser" do
    post agent_storefront_cart_items_path, params: { product_id: "variant-#{variants(:tee_black_m).id}", quantity: 2 }, headers: @headers
    assert_equal [ [ "variant-#{variants(:tee_black_m).id}", 2 ] ], response.parsed_body["items"].map { |item| [ item["product_id"], item["quantity"] ] }

    post agent_storefront_cart_items_path, params: { product_id: "product-#{products(:mug).slug}", quantity: 1 }, headers: @headers
    assert_equal 2, response.parsed_body["items"].size

    post agent_storefront_cart_items_path, params: { product_id: "variant-#{variants(:tee_white_s).id}", quantity: 1 }, headers: @headers
    assert_response :conflict
    assert_includes response.parsed_body["in_stock"], "variant-#{variants(:tee_black_s).id}"

    post agent_storefront_cart_items_path, params: { product_id: "product-#{products(:tee).slug}", quantity: 1 }, headers: @headers
    assert_response :unprocessable_entity

    patch agent_storefront_cart_item_path("product-#{products(:mug).slug}"), params: { quantity: 3 }, headers: @headers
    delete agent_storefront_cart_item_path("variant-#{variants(:tee_black_m).id}"), headers: @headers
    assert_equal [ [ "product-#{products(:mug).slug}", 3 ] ], response.parsed_body["items"].map { |item| [ item["product_id"], item["quantity"] ] }

    get agent_storefront_cart_path, headers: @headers.merge("X-Agent-Session" => "someone-else")
    assert_empty response.parsed_body["items"]

    get handoff_agent_storefront_cart_path, headers: @headers
    claim = response.parsed_body["handoffs"].sole["url"]
    get claim
    assert_redirected_to new_checkout_path
    follow_redirect!
    assert_select "aside", /Morning Mug/
  end

  test "a signed-in customer's own orders; a guest has none" do
    enable_customer_accounts
    order = orders(:paid)
    order.update!(customer: customers(:casey))

    get agent_storefront_orders_path, headers: @headers
    assert_empty response.parsed_body["orders"]

    get agent_storefront_orders_path, headers: @headers.merge("X-Agent-Customer" => customers(:casey).email_address)
    assert_equal [ order.name ], response.parsed_body["orders"].map { |each| each["order_id"] }

    get agent_storefront_order_path(orders(:pending).number), headers: @headers.merge("X-Agent-Customer" => customers(:casey).email_address)
    assert_response :not_found
  end

  test "policies, delivery options and the profile" do
    Store.current.update!(refund_policy: "Returns within 30 days.\n\nDamaged items are replaced for free.")
    get agent_storefront_policies_path(query: "damaged"), headers: @headers
    assert_equal "Damaged items are replaced for free.", response.parsed_body["policies"].first["content"]

    get agent_storefront_fulfillment_path(product_ids: [ "product-#{products(:mug).slug}" ]), headers: @headers
    assert_equal 5.0, response.parsed_body["options"].first["fee"]

    get agent_storefront_preferences_path, headers: @headers
    assert_equal "guest", response.parsed_body["user_id"]
  end
end
