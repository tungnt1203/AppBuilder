require "test_helper"

class Admin::StripeConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @gateway = FakeStripeGateway.new
    gateway = @gateway
    StripeGateway.define_singleton_method(:build) { |_key| gateway }
  end

  test "the owner connects and disconnects Stripe from settings" do
    sign_in_as users(:owner)
    get edit_admin_settings_path
    assert_select "input[name=secret_key]"

    post admin_stripe_connection_path, params: { secret_key: "sk_test_123" }
    assert_redirected_to edit_admin_settings_path(anchor: "payments")
    assert Store.current.stripe_connected?

    follow_redirect!
    assert_select "strong", "Fake Shop LLC"
    assert_select "span", "Test mode"

    delete admin_stripe_connection_path
    assert_not Store.current.stripe_connected?
  end

  test "a key Stripe refuses shows why" do
    sign_in_as users(:owner)
    @gateway.error = "Invalid API Key provided"
    post admin_stripe_connection_path, params: { secret_key: "sk_live_nope" }

    assert_match "Invalid API Key provided", flash[:alert]
    assert_not Store.current.stripe_connected?
  end

  test "staff can't connect Stripe" do
    sign_in_as users(:staff)
    post admin_stripe_connection_path, params: { secret_key: "sk_test_123" }
    assert_redirected_to admin_root_path
    assert_not Store.current.stripe_connected?
  end

  test "refunding a card order sends the money back through Stripe" do
    connect_fake_stripe(@gateway)
    order = orders(:paid).tap { |o| o.update!(payment_method: "stripe", payment_reference: "pi_5") }
    sign_in_as users(:owner)

    get admin_order_path(order)
    assert_select "a[href='https://dashboard.stripe.com/test/payments/pi_5']"
    assert_select "button", text: "Mark as paid", count: 0

    post admin_order_refund_path(order)
    assert order.reload.refunded?
    assert_equal [ "pi_5" ], @gateway.refunds
  end
end
