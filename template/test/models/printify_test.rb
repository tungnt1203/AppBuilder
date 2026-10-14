require "test_helper"

class PrintifyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper, ActionMailer::TestHelper

  setup { @printify = connect_fake_printify }

  test "connecting checks the token and picks the only shop" do
    Store.current.update!(printify_token: nil, printify_shop_id: nil)
    shops = Store.current.connect_printify!(" fake-token ")

    assert_equal 1, shops.size
    assert_equal [ "fake-token", "4242", "Fake Printify shop" ], Store.current.values_at(:printify_token, :printify_shop_id, :printify_shop_title)
    assert Store.current.printify_connected?

    @printify.error = "Printify didn't accept the token."
    assert_raises(PrintifyGateway::Error) { Store.current.connect_printify!("bad") }
    assert_equal "fake-token", Store.current.reload.printify_token
  end

  test "importing makes the product, its variants, prices, costs and a photo per color" do
    product = Printify::Import.new.call("pf-tee")

    assert_equal [ "Sunset Tee", "active", "pf-tee" ], [ product.title, product.status, product.printify_product_id ]
    assert_equal "Soft cotton.\n\nPrinted to order.", product.description
    assert_equal [ [ "Color", %w[ Black White ] ], [ "Size", %w[ S M ] ] ], product.options.map { |_, name, values| [ name, values ] }

    black_s = product.variant_for(%w[ Black S ])
    assert_equal [ 2500, 1150, "PF-BLK-S", 1001, true ], [ black_s.price_cents, black_s.cost_cents, black_s.sku, black_s.printify_variant_id, black_s.available ]
    assert_equal 2700, product.variant_for(%w[ White S ]).price_cents
    assert_not product.variant_for(%w[ White M ]).available, "Printify doesn't make it"

    assert_equal 3, product.images.count
    assert_equal "sunset-tee-white.jpg", product.image_for(product.variant_for(%w[ White S ])).filename.to_s
    assert_equal %w[ Black White ], product.option_images.keys
  end

  test "importing again keeps the owner's title and prices, and brings costs and new variants" do
    product = Printify::Import.new.call("pf-tee")
    product.update!(title: "Golden Hour Tee")
    product.variant_for(%w[ Black S ]).update!(price: "29")

    @printify.product_data["variants"].find { |variant| variant["id"] == 1001 }["cost"] = 1300
    @printify.product_data["variants"].find { |variant| variant["id"] == 1004 }["is_enabled"] = true
    Printify::Import.new.call("pf-tee")

    product.reload
    black_s = product.variant_for(%w[ Black S ])
    assert_equal [ "Golden Hour Tee", 2900, 1300 ], [ product.title, black_s.price_cents, black_s.cost_cents ]
    assert product.variant_for(%w[ White M ]).available
    assert_equal 3, product.images.count, "photos aren't added twice"
  end

  test "a paid order goes to Printify and into production, then ships with Printify's tracking" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ White S ]), quantity: 2, status: "pending")

    perform_enqueued_jobs(only: Order::FulfillJob) { order.mark_paid! }

    sent = @printify.orders.sole
    assert_equal [ order.number.to_s, 1, false ], sent.values_at(:external_id, :shipping_method, :send_shipping_notification)
    assert_equal [ { product_id: "pf-tee", variant_id: 1003, quantity: 2 } ], sent[:line_items]
    assert_equal [ "Robin", "Buyer", "US", "78701" ], sent[:address_to].values_at(:first_name, :last_name, :country, :zip)
    assert_equal [ "pf-order-1" ], @printify.sent_to_production
    assert order.reload.in_production?
    assert_equal "pf-order-1", order.printify_order_id

    Order::TrackShipmentsJob.perform_now
    assert order.reload.in_production?, "nothing shipped yet"

    @printify.shipments = [ { "carrier" => "usps", "number" => "9400111", "url" => "https://tools.usps.com/go/TrackConfirmAction?tLabels=9400111" } ]
    assert_enqueued_email_with OrderMailer, :shipped, args: [ order ] do
      Order::TrackShipmentsJob.perform_now
    end
    assert order.reload.shipped?
    assert_equal [ "usps", "9400111" ], [ order.carrier, order.tracking_number ]
  end

  test "a failure stays on the order for staff, and nothing is sent for orders without Printify items" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black M ]))
    @printify.error = "Address is invalid"

    Printify::Fulfillment.new(order).submit!
    assert_equal "Address is invalid", order.reload.fulfillment_error
    assert order.paid?
    assert_equal "fulfillment_failed", order.events.last.action

    @printify.error = nil
    Printify::Fulfillment.new(order).submit!
    assert order.reload.in_production?
    assert_nil order.fulfillment_error

    other = orders(:paid)
    assert_not Printify::Fulfillment.new(other).applies?
  end

  test "an order Printify already has (sent twice, or a retry after a lost answer) is taken, not failed" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black M ]))
    @printify.existing_orders = [ { "id" => "pf-earlier", "status" => "on-hold", "metadata" => { "shop_order_id" => order.number.to_s } } ]

    Printify::Fulfillment.new(order).submit!
    assert order.reload.in_production?
    assert_equal [ "pf-earlier", nil ], [ order.printify_order_id, order.fulfillment_error ]
    assert_equal [ "pf-earlier" ], @printify.sent_to_production, "it was waiting in Printify; the shop sends it to production"
    assert_not_includes order.events.map(&:action), "fulfillment_failed"
  end

  test "importing puts Color first, with Printify's swatches, and a re-import keeps the order" do
    @printify.product_data["options"].reverse!
    product = Printify::Import.new.call("pf-tee")
    assert_equal %w[ Color Size ], product.option_names
    assert_equal({ "Black" => "#000000", "White" => "#ffffff" }, product.option_colors)

    product.update!(option1_name: "Size", option1_values: %w[ S M ], option2_name: "Color", option2_values: %w[ Black White ])
    variants = product.variants.reload.map(&:id).sort
    Printify::Import.new.call("pf-tee")
    assert_equal %w[ Size Color ], product.reload.option_names
    assert_equal variants, product.variants.reload.map(&:id).sort
  end

  test "owners can review orders in Printify before they're printed" do
    Store.current.update!(printify_send_to_production: false)
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]))

    Printify::Fulfillment.new(order).submit!
    assert_equal 1, @printify.orders.size
    assert_empty @printify.sent_to_production
  end

  private
    def place_order(variant, quantity: 1, status: "paid")
      Order.create!(email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St", shipping_city: "Austin",
        shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US", currency: "USD", payment_method: "manual",
        status:, paid_at: (Time.current if status == "paid"),
        subtotal_cents: variant.price_cents * quantity, shipping_cents: 0, total_cents: variant.price_cents * quantity,
        line_items: [ LineItem.new(variant:, product_title: variant.product.title, variant_title: variant.title, unit_price_cents: variant.price_cents, quantity:) ])
    end
end
