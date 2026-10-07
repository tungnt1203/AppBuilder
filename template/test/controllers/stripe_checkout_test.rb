require "test_helper"

class StripeCheckoutTest < ActionDispatch::IntegrationTest
  ADDRESS = { email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St",
    shipping_city: "Austin", shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }.freeze

  setup { @gateway = connect_fake_stripe }

  test "a card checkout goes on to Stripe and keeps the cart for a buyer who backs out" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    get new_checkout_path
    assert_select "input[type=radio][name='checkout[payment_method]']", 2
    assert_select "form[data-turbo=false][data-controller=leave-frame]"

    post checkout_path, params: { checkout: ADDRESS.merge(payment_method: "stripe") }

    order = Order.last
    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_1"
    assert_equal "cs_test_1", order.stripe_checkout_session_id
    assert_equal cart_url, @gateway.checkouts.last[:cancel_url]
    assert_match "session_id={CHECKOUT_SESSION_ID}", @gateway.checkouts.last[:success_url]
    assert_equal 1, Cart.last.items.count
  end

  test "coming back from Stripe after paying shows the order as paid" do
    order = card_order
    @gateway.paid = true

    get order_path(order, placed: 1, session_id: "cs_test_1")

    assert order.reload.paid?
    assert_equal "pi_test_1", order.payment_reference
    assert_select "p", /Thank you/
  end

  test "an unpaid card order offers to pay again" do
    order = card_order
    get order_path(order)
    assert_select "button", /Pay \$29.00/

    post order_payment_path(order)
    assert_redirected_to %r{\Ahttps://checkout.stripe.com/}
    assert_equal order_url(order), @gateway.checkouts.last[:cancel_url]
  end

  test "when Stripe is down the buyer lands on the order page to try again" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    @gateway.error = "API unavailable"
    post checkout_path, params: { checkout: ADDRESS.merge(payment_method: "stripe") }

    assert_redirected_to order_path(Order.last)
    assert_equal I18n.t("orders.payment_not_started"), flash[:alert]
  end

  test "manual payment still works next to cards" do
    post cart_items_path, params: { variant_id: variants(:mug).id }
    post checkout_path, params: { checkout: ADDRESS.merge(payment_method: "manual") }

    assert_redirected_to order_path(Order.last, placed: 1)
    assert_not Order.last.card?
  end

  private
    def card_order
      orders(:pending).tap { |order| order.update!(payment_method: "stripe", stripe_checkout_session_id: "cs_test_1") }
    end
end
