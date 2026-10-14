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
    assert_equal "sunset-tee-white.png", product.image_for(product.variant_for(%w[ White S ])).filename.to_s
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
    assert_equal 1150 + 475, order.fulfillment_cost_cents
    assert_equal order.total_cents - 1625, order.margin_cents

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

  test "a new design in Printify brings new mockups; the owner's own photos stay" do
    product = Printify::Import.new.call("pf-tee")
    product.images.attach(io: file_fixture("product.png").open, filename: "lifestyle.png", content_type: "image/png")
    product.save!
    own = product.images.attachments.order(:id).last

    @printify.product_data["images"].each { |image| image["src"] = image["src"].sub(".jpg", "-v2.jpg") }
    @printify.error = "Couldn't download a mockup (500)"
    @printify.define_singleton_method(:product) { |_shop, _id| product_data } # only downloads fail
    assert_raises(PrintifyGateway::Error) { Printify::Import.new.call("pf-tee") }
    assert_equal 4, product.reload.images.count, "a failed download changes nothing"

    @printify.error = nil
    Printify::Import.new.call("pf-tee")
    product.reload
    assert_equal 4, product.images.count
    assert_includes product.images.attachments.map(&:id), own.id
    assert product.images.blobs.all? { |blob| blob.id == own.blob_id || blob.metadata["printify_src"].end_with?("-v2.jpg") }
    assert_equal "sunset-tee-white.png", product.image_for(product.variant_for(%w[ White S ])).filename.to_s
  end

  test "a product of a few hundred variants can be imported" do
    sizes = %w[ XS S M L XL 2XL 3XL 4XL 5XL ]
    colors = 30.times.map { |index| { "id" => 600 + index, "title" => "Color #{index}", "colors" => [ "#0000#{format("%02x", index)}" ] } }
    @printify.product_data["options"] = [
      { "name" => "Colors", "type" => "color", "values" => colors },
      { "name" => "Sizes", "type" => "size", "values" => sizes.each_with_index.map { |size, index| { "id" => 700 + index, "title" => size } } }
    ]
    @printify.product_data["variants"] = colors.product(sizes.each_index.to_a).each_with_index.map do |(color, size), index|
      { "id" => 5000 + index, "sku" => "V#{index}", "price" => 2500, "cost" => 1100, "is_enabled" => true, "is_available" => true, "options" => [ color["id"], 700 + size ] }
    end

    product = Printify::Import.new.call("pf-tee")
    assert_equal 270, product.variants.count
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

  test "owners can review orders in Printify before they're printed; the order stays cancellable until then" do
    Store.current.update!(printify_send_to_production: false)
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]))

    Printify::Fulfillment.new(order).submit!
    assert_equal 1, @printify.orders.size
    assert_empty @printify.sent_to_production
    assert order.reload.paid?
    assert_equal "sent_to_printify", order.events.last.action
    assert order.can_cancel?

    @printify.status = "on-hold"
    Order::TrackShipmentsJob.perform_now
    assert order.reload.paid?

    @printify.status = "in-production"
    Order::TrackShipmentsJob.perform_now
    assert order.reload.in_production?, "approved in Printify"
  end

  test "cancelling or refunding cancels the order in Printify, or tells staff it couldn't" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]))
    order.update!(printify_order_id: "pf-1")
    order.cancel!
    assert_equal [ "pf-1" ], @printify.cancelled
    assert_equal "printify_cancelled", order.events.last.action

    printing = place_order(product.variant_for(%w[ Black M ]), status: "in_production")
    printing.update!(printify_order_id: "pf-2")
    @printify.error = "Order can't be cancelled"
    printing.refund!(stripe: false)
    assert printing.reload.refunded?
    assert_match "cancel it in Printify", printing.fulfillment_error
  end

  test "an order Printify splits ships once every package has, with all the tracking" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]), status: "in_production")
    order.update!(printify_order_id: "pf-3")

    @printify.status = "partially-fulfilled"
    @printify.shipments = [ { "carrier" => "usps", "number" => "111", "url" => "https://track.example/111" } ]
    Printify::Fulfillment.new(order).sync!
    assert order.reload.in_production?

    @printify.status = "fulfilled"
    @printify.shipments << { "carrier" => "ups", "number" => "222", "url" => "https://track.example/222" }
    Printify::Fulfillment.new(order).sync!
    assert order.reload.shipped?
    assert_equal [ "usps, ups", "111, 222", "https://track.example/111" ], [ order.carrier, order.tracking_number, order.tracking_url ]

    @printify.shipments.first["delivered_at"] = Time.current.iso8601
    Printify::Fulfillment.new(order).sync!
    assert order.reload.shipped?, "one package still on its way"
    @printify.shipments.last["delivered_at"] = Time.current.iso8601
    Printify::Fulfillment.new(order).sync!
    assert order.reload.delivered?
  end

  test "staff hear when Printify needs something" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]), status: "in_production")
    order.update!(printify_order_id: "pf-4")

    @printify.status = "payment-not-received"
    2.times { Printify::Fulfillment.new(order).sync! }
    assert_match "waiting for your payment", order.reload.fulfillment_error
    assert_equal 1, order.events.where(action: "fulfillment_failed").count
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
