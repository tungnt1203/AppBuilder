require "test_helper"

class OrderLookupsTest < ActionDispatch::IntegrationTest
  ADDRESS = { email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St", shipping_city: "Austin",
    shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }.freeze

  test "a buyer asks for their orders by email, then opens the emailed link and reaches each order" do
    post cart_items_path, params: { variant_id: 101 }
    post checkout_path, params: { idempotency_key: "k1", checkout: ADDRESS.merge(payment_method: "manual") }
    order = @platform.orders.values.sole

    get root_path
    assert_select "footer a[href=?]", new_order_lookup_path, "Find my order"
    get new_order_lookup_path
    assert_select "input[type=email][name=email]"

    post order_lookups_path, params: { email: " Robin@Example.com " }
    assert_redirected_to sent_order_lookup_path
    follow_redirect!
    assert_select "h1", "Check your email"
    assert_select "p", /If Robin@Example.com has orders with us/
    token = @platform.order_lookups.keys.sole

    get order_lookup_path(token)
    assert_response :success
    assert_select "p", /Orders placed with robin@example.com/
    assert_select "a[href=?]", order_path(order["token"]) do
      assert_select "span", order["name"]
      assert_select "p", /Cat Tee/
    end
  end

  test "an email without orders sees the same answer, and nothing is sent" do
    post order_lookups_path, params: { email: "nobody@example.com" }
    follow_redirect!
    assert_select "h1", "Check your email"
    assert_empty @platform.order_lookups
  end

  test "an email that isn't one is asked for again" do
    post order_lookups_path, params: { email: "robin" }
    assert_response :unprocessable_entity
    assert_select "#email_error", "Email isn't a valid email"
    assert_select "input[name=email][value=robin][aria-invalid=true]"
  end

  test "an expired link asks for a new one" do
    get order_lookup_path("lookup-gone")
    assert_response :not_found
    assert_select "h1", "This link has expired"
    assert_select "a[href=?]", new_order_lookup_path
  end
end
