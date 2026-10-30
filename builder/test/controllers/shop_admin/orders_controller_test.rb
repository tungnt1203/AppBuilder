require "test_helper"

class ShopAdmin::OrdersControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "needs a sign in, and the shop's people only" do
    sign_out
    get shop_admin_orders_path
    assert_redirected_to new_session_path(shop_id: nil)

    sign_in_as users(:owner) # runs the builder, not this shop
    get shop_admin_orders_path
    assert_response :not_found
  end

  test "ticked orders take a step together, and those that can't are counted and left" do
    get shop_admin_orders_path
    assert_select "input[type=checkbox][name='order_tokens[]'][value=?]", orders(:paid).token

    patch shop_admin_order_batch_path, params: { order_tokens: [ orders(:paid).token, orders(:shipped).token ], batch_action: "in_production" }
    assert_redirected_to shop_admin_orders_path
    assert_equal "1 order is in production. 1 couldn't take that step and is as it was.", flash[:notice]
    assert orders(:paid).reload.in_production?
    assert orders(:shipped).reload.shipped?

    patch shop_admin_order_batch_path, params: { order_tokens: [ orders(:shipped).token ], batch_action: "delivered" }
    assert orders(:shipped).reload.delivered?
    assert_equal users(:cats_staff), orders(:shipped).events.last.user

    patch shop_admin_order_batch_path, params: { order_tokens: [ orders(:pending).token ], batch_action: "refund" }
    assert orders(:pending).reload.pending?
  end

  test "lists, filters and searches orders" do
    get shop_admin_orders_path
    assert_select "a[href=?]", shop_admin_order_path(orders(:shipped))

    get shop_admin_orders_path(filter: "to_ship")
    assert_select "a[href=?]", shop_admin_order_path(orders(:paid))
    assert_select "a[href=?]", shop_admin_order_path(orders(:pending)), count: 0

    get shop_admin_orders_path(q: "1001")
    assert_select "a[href=?]", shop_admin_order_path(orders(:pending))
    assert_select "a[href=?]", shop_admin_order_path(orders(:paid)), count: 0
  end

  test "shows an order with the actions it can take" do
    get shop_admin_order_path(orders(:pending))

    assert_response :success
    assert_select "form[action=?]", shop_admin_order_payment_path(orders(:pending))
    assert_select "form[action=?]", shop_admin_order_shipment_path(orders(:pending)), count: 0
  end

  test "the timeline says who did what, and a cancelled order isn't said to be in the making" do
    order = orders(:pending)
    order.record :placed
    order.record "sent_to_printify", message: "Printify pf-1"
    order.update!(printify_order_id: "pf-1", status: "cancelled")

    get shop_admin_order_path(order)
    assert_select "li p.text-xs", text: /, Buyer/, minimum: 1
    assert_select "li p.text-xs", text: /, Automatic/, minimum: 1
    assert_match "This order is in Printify too", response.body
    assert_no_match "Printify is making this order", response.body
  end

  test "a buyer's photo shows on its line, to download for printing" do
    upload = BuyerUpload.take(Rack::Test::UploadedFile.new(file_fixture("product.png"), "image/png"))
    products(:tee).update!(buyer_inputs: [ { "label" => "Your photo", "kind" => "photo" } ])
    line_items(:pending_tee).update!(properties: { "your_photo" => upload.token, "your_photo_crop" => "1.5,0.2,0.8" })

    get shop_admin_order_path(orders(:pending))
    assert_select "p", "Your photo: Added"
    assert_select "p", /framed at 1.5× around 20%, 80%/
    assert_select "a[href*='disposition=attachment']", "Download the photo"
  end

  test "a paid order that hasn't gone to Printify yet can be sent now" do
    printify = connect_fake_printify
    variant = Printify::Import.new.call("pf-tee").variant_for(%w[ Black S ])
    order = Order.create!(email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St", shipping_city: "Austin",
      shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US", phone: "5125550100", currency: "USD", payment_method: "manual",
      status: "paid", paid_at: Time.current, subtotal_cents: 2500, shipping_cents: 0, total_cents: 2500,
      line_items: [ LineItem.new(variant:, product_title: "Sunset Tee", variant_title: variant.title, unit_price_cents: 2500, quantity: 1) ])

    get shop_admin_order_path(order)
    assert_select "button", "Send to Printify now"

    post shop_admin_order_fulfillment_path(order)
    assert_equal 1, printify.orders.size
    assert order.reload.printify_order_id.present?
  end

  test "a personalized line shows the print files that went to Printify, a side each" do
    line_items(:pending_tee).print_files.attach(io: file_fixture("product.png").open, filename: "1001-1-front.png", content_type: "image/png")
    line_items(:pending_tee).print_files.attach(io: file_fixture("product.png").open, filename: "1001-1-back.png", content_type: "image/png")

    get shop_admin_order_path(orders(:pending))
    assert_select "img[alt='Print file, Front']"
    assert_select "img[alt='Print file, Back']"
    assert_select "a[href*='disposition=attachment']", text: "Download the print file", count: 2
  end

  test "marks paid, then ships with tracking and emails the buyer" do
    order = orders(:pending)
    post shop_admin_order_payment_path(order)
    assert order.reload.paid?

    assert_enqueued_email_with OrderMailer, :shipped, args: [ order ] do
      post shop_admin_order_shipment_path(order), params: { carrier: "USPS", tracking_number: "9400 22", tracking_url: "https://example.com/t" }
    end
    assert_redirected_to shop_admin_order_path(order)
    assert order.reload.shipped?
    assert_equal users(:cats_staff), order.events.last.user
  end

  test "a step that doesn't fit the order's status is refused" do
    post shop_admin_order_delivery_path(orders(:pending))

    assert_redirected_to shop_admin_order_path(orders(:pending))
    assert orders(:pending).reload.pending?
    assert_match(/can't be done/, flash[:alert])
  end

  test "a bad tracking link is refused" do
    post shop_admin_order_shipment_path(orders(:paid)), params: { carrier: "UPS", tracking_number: "1", tracking_url: "ftp://x" }
    assert orders(:paid).reload.paid?
  end

  test "cancel, refund and production" do
    post shop_admin_order_cancellation_path(orders(:pending))
    assert orders(:pending).reload.cancelled?

    post shop_admin_order_production_path(orders(:paid))
    assert orders(:paid).reload.in_production?

    post shop_admin_order_refund_path(orders(:shipped))
    assert orders(:shipped).reload.refunded?
  end

  test "a paid card order is cancelled with its refund, and a refunded one's items go back in stock" do
    gateway = connect_fake_stripe
    orders(:paid).update!(payment_method: "stripe", payment_reference: "pi_4")
    get shop_admin_order_path(orders(:paid))
    assert_select "button", text: "Cancel and refund"

    post shop_admin_order_cancellation_path(orders(:paid))
    assert orders(:paid).reload.cancelled?
    assert_equal [ "pi_4" ], gateway.refunds

    order = orders(:shipped)
    order.line_items.first.variant.update!(track_inventory: true, inventory_quantity: 0)
    post shop_admin_order_refund_path(order)
    get shop_admin_order_path(order)
    assert_select "button", text: "Put items back in stock"

    assert_difference -> { order.line_items.first.variant.reload.inventory_quantity }, order.line_items.first.quantity do
      post shop_admin_order_restock_path(order)
    end
    assert_redirected_to shop_admin_order_path(order)
  end

  test "saves a staff note and corrects the address" do
    patch shop_admin_order_path(orders(:paid)), params: { order: { staff_note: "Gift wrap", shipping_address1: "2 Main St" } }

    assert_redirected_to shop_admin_order_path(orders(:paid))
    assert_equal [ "Gift wrap", "2 Main St" ], orders(:paid).reload.values_at(:staff_note, :shipping_address1)
    assert_equal "edited", orders(:paid).events.last.action
  end
end
