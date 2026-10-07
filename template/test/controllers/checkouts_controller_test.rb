require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  ADDRESS = { email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St",
    shipping_city: "Austin", shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }.freeze

  test "an empty cart goes back to the cart" do
    get new_checkout_path
    assert_redirected_to cart_path
  end

  test "a guest checks out without an account and lands on the order page" do
    post cart_items_path, params: { variant_id: variants(:tee_black_s).id, quantity: 2 }

    get new_checkout_path
    assert_response :success
    assert_select "select[name='checkout[shipping_country]'] option", 3

    assert_difference -> { Order.count } do
      post checkout_path, params: { checkout: ADDRESS }
    end
    order = Order.last
    assert_redirected_to order_path(order, placed: 1)
    assert_equal 4800 + 700, order.total_cents

    follow_redirect!
    assert_select "h1", /#{order.number}/
  end

  test "mistakes show the form again with the cart intact" do
    post cart_items_path, params: { variant_id: variants(:mug).id }

    assert_no_difference -> { Order.count } do
      post checkout_path, params: { checkout: ADDRESS.merge(email: "nope") }
    end
    assert_response :unprocessable_entity
    assert_equal 1, Cart.last.items.count
  end

  test "prices from the form are ignored" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    post checkout_path, params: { checkout: ADDRESS.merge(total_cents: 1, subtotal_cents: 1) }

    assert_equal 1500 + 500, Order.last.total_cents
  end

  test "a signed-in customer's order is theirs" do
    enable_customer_accounts
    sign_in_as_customer customers(:casey)
    post cart_items_path, params: { variant_id: variants(:mug).id }
    post checkout_path, params: { checkout: ADDRESS }

    assert_equal customers(:casey), Order.last.customer
  end
end
