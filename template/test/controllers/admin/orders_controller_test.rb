require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { sign_in_as users(:staff) }

  test "needs a staff sign in, and customers aren't staff" do
    sign_out
    enable_customer_accounts
    sign_in_as_customer customers(:casey)

    get admin_orders_path
    assert_redirected_to new_admin_session_path
  end

  test "lists, filters and searches orders" do
    get admin_orders_path
    assert_select "a[href=?]", admin_order_path(orders(:shipped))

    get admin_orders_path(filter: "to_ship")
    assert_select "a[href=?]", admin_order_path(orders(:paid))
    assert_select "a[href=?]", admin_order_path(orders(:pending)), count: 0

    get admin_orders_path(q: "1001")
    assert_select "a[href=?]", admin_order_path(orders(:pending))
    assert_select "a[href=?]", admin_order_path(orders(:paid)), count: 0
  end

  test "shows an order with the actions it can take" do
    get admin_order_path(orders(:pending))

    assert_response :success
    assert_select "form[action=?]", admin_order_payment_path(orders(:pending))
    assert_select "form[action=?]", admin_order_shipment_path(orders(:pending)), count: 0
  end

  test "marks paid, then ships with tracking and emails the buyer" do
    order = orders(:pending)
    post admin_order_payment_path(order)
    assert order.reload.paid?

    assert_enqueued_email_with OrderMailer, :shipped, args: [ order ] do
      post admin_order_shipment_path(order), params: { carrier: "USPS", tracking_number: "9400 22", tracking_url: "https://example.com/t" }
    end
    assert_redirected_to admin_order_path(order)
    assert order.reload.shipped?
    assert_equal users(:staff), order.events.last.user
  end

  test "a step that doesn't fit the order's status is refused" do
    post admin_order_delivery_path(orders(:pending))

    assert_redirected_to admin_order_path(orders(:pending))
    assert orders(:pending).reload.pending?
    assert_match(/can't be done/, flash[:alert])
  end

  test "a bad tracking link is refused" do
    post admin_order_shipment_path(orders(:paid)), params: { carrier: "UPS", tracking_number: "1", tracking_url: "ftp://x" }
    assert orders(:paid).reload.paid?
  end

  test "cancel, refund and production" do
    post admin_order_cancellation_path(orders(:pending))
    assert orders(:pending).reload.cancelled?

    post admin_order_production_path(orders(:paid))
    assert orders(:paid).reload.in_production?

    post admin_order_refund_path(orders(:shipped))
    assert orders(:shipped).reload.refunded?
  end

  test "a paid card order is cancelled with its refund, and a refunded one's items go back in stock" do
    gateway = connect_fake_stripe
    orders(:paid).update!(payment_method: "stripe", payment_reference: "pi_4")
    get admin_order_path(orders(:paid))
    assert_select "button", text: "Cancel and refund"

    post admin_order_cancellation_path(orders(:paid))
    assert orders(:paid).reload.cancelled?
    assert_equal [ "pi_4" ], gateway.refunds

    order = orders(:shipped)
    order.line_items.first.variant.update!(track_inventory: true, inventory_quantity: 0)
    post admin_order_refund_path(order)
    get admin_order_path(order)
    assert_select "button", text: "Put items back in stock"

    assert_difference -> { order.line_items.first.variant.reload.inventory_quantity }, order.line_items.first.quantity do
      post admin_order_restock_path(order)
    end
    assert_redirected_to admin_order_path(order)
  end

  test "saves a staff note and corrects the address" do
    patch admin_order_path(orders(:paid)), params: { order: { staff_note: "Gift wrap", shipping_address1: "2 Main St" } }

    assert_redirected_to admin_order_path(orders(:paid))
    assert_equal [ "Gift wrap", "2 Main St" ], orders(:paid).reload.values_at(:staff_note, :shipping_address1)
    assert_equal "edited", orders(:paid).events.last.action
  end
end
