require "test_helper"

class PrintifyTest < ActiveSupport::TestCase
  setup { in_shop }

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

    assert_equal [ "Sunset Tee", "draft", "pf-tee" ], [ product.title, product.status, product.printify_product_id ]
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

  test "the products Printify made for the shop's personalized orders aren't listed to import" do
    order = place_order(Printify::Import.new.call("pf-tee").variants.first)
    made = [ @printify.product_data.merge("id" => "pf-made", "title" => "API #{order.name} - Robin Buyer"),
      @printify.product_data.merge("id" => "pf-other", "title" => "API #99999 - Someone"), @printify.product_data ]
    @printify.define_singleton_method(:products) { |_shop_id, page: 1| { "data" => made, "last_page" => 1 } }

    items, = Printify::Import.new.list
    assert_equal [ "pf-other", "pf-tee" ], items.pluck(:id), "only titles of this shop's own orders"
  end

  test "the description reads for buyers: points as a list, without the lines about print providers" do
    @printify.product_data["description"] = "<p>Soft tee.</p><p>Disclaimer:<br>- Sleeve prints are made with DTF by the print providers OPT OnDemand and Shirt Monkey.<br></p>" \
      "<p>.: 100% cotton<br>.: Tear-away label &amp; no side seams</p>"
    product = Printify::Import.new.call("pf-tee")

    assert_equal "Soft tee.\n\n- 100% cotton\n- Tear-away label & no side seams", product.description
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
    assert_equal [ "#{Store.current.uid}-#{order.number}", 1, false ], sent.values_at(:external_id, :shipping_method, :send_shipping_notification)
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

  test "when Printify can't be reached the order is sent again later by itself; a refusal waits for staff" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black M ]), status: "pending")
    refused = place_order(product.variant_for(%w[ Black M ]), status: "pending")
    @printify.error = PrintifyGateway::Unavailable.new("Printify answered 503")

    order.mark_paid!
    assert_enqueued_with(job: Order::FulfillJob) { perform_enqueued_jobs(only: Order::FulfillJob) }
    assert_equal "Printify answered 503", order.reload.fulfillment_error
    assert order.paid?

    assert_enqueued_with(job: Order::FulfillJob) { perform_enqueued_jobs(only: Order::FulfillJob) }
    assert_equal 1, order.events.where(action: "fulfillment_failed").count, "told once, not on every try"

    @printify.error = nil
    perform_enqueued_jobs(only: Order::FulfillJob)
    assert order.reload.in_production?
    assert_nil order.fulfillment_error

    @printify.error = "Address is invalid"
    in_shop # running jobs leaves the test's shop
    refused.mark_paid!
    assert_no_enqueued_jobs(only: Order::FulfillJob) { perform_enqueued_jobs(only: Order::FulfillJob) }
    assert_equal "Address is invalid", refused.reload.fulfillment_error
  end

  test "an order Printify already has (sent twice, or a retry after a lost answer) is taken, not failed" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black M ]))
    @printify.existing_orders = [ { "id" => "pf-earlier", "status" => "on-hold", "metadata" => { "shop_order_id" => "#{Store.current.uid}-#{order.number}" } } ]

    Printify::Fulfillment.new(order).submit!
    assert order.reload.in_production?
    assert_equal [ "pf-earlier", nil ], [ order.printify_order_id, order.fulfillment_error ]
    assert_equal [ "pf-earlier" ], @printify.sent_to_production, "it was waiting in Printify; the shop sends it to production"
    assert_not_includes order.events.map(&:action), "fulfillment_failed"
  end

  test "another shop of the owner sending the same order number to the same Printify shop doesn't clash" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black M ]))
    @printify.existing_orders = [ { "id" => "pf-other-shop", "status" => "on-hold", "metadata" => { "shop_order_id" => "othershop-#{order.number}" } } ]

    Printify::Fulfillment.new(order).submit!
    assert_equal "pf-order-1", order.reload.printify_order_id, "its own order, not the other shop's"
    assert_equal "#{Store.current.uid}-#{order.number}", @printify.orders.sole[:external_id]
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

  test "an order already cancelled in Printify isn't reported as one Printify refused to cancel" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]))
    order.update!(printify_order_id: "pf-6")
    @printify.define_singleton_method(:cancel_order) { |*| raise PrintifyGateway::Error, "Order status does not allow cancellation" }
    @printify.status = "canceled"

    order.cancel!
    assert_nil order.reload.fulfillment_error
    assert_equal "printify_cancelled", order.events.last.action
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

  test "an order with the shop's own items too waits for staff to send them" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ Black S ]), status: "in_production")
    order.line_items.create!(variant: variants(:mug), product_title: "Mug", unit_price_cents: 1200, quantity: 1)
    order.update!(printify_order_id: "pf-5")
    @printify.shipments = [ { "carrier" => "usps", "number" => "333", "url" => "https://track.example/333" } ]

    2.times { Printify::Fulfillment.new(order).sync! }
    assert order.reload.in_production?
    assert_equal [ "usps 333" ], order.events.where(action: "printify_shipped").pluck(:message)
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

  test "an order with text the buyer typed waits for staff, who link the order they made in Printify" do
    product = Printify::Import.new.call("pf-tee")
    product.update!(buyer_inputs: [ { "key" => "print_name", "label" => "Name on the shirt", "required" => true, "max_length" => 20 } ])
    order = place_order(product.variant_for(%w[ White S ]), status: "pending")
    order.line_items.sole.update!(properties: { "print_name" => "Ada" })

    perform_enqueued_jobs(only: Order::FulfillJob) { order.mark_paid! }
    assert_empty @printify.orders
    assert Printify::Fulfillment.new(order).needs_personalizing?

    @printify.error = "Printify answered 404"
    assert_nil Printify::Fulfillment.new(order).link!("nope")
    assert_nil order.reload.printify_order_id

    @printify.error = nil
    assert_equal "5a96f649b2439217d070f507", Printify::Fulfillment.new(order).link!("https://printify.com/app/order/5a96f649b2439217d070f507")
    assert_equal "5a96f649b2439217d070f507", order.reload.printify_order_id
    assert order.in_production?
    assert_nil order.fulfillment_error
    assert_equal 1625, order.fulfillment_cost_cents
  end

  test "an order with what the buyer added goes by itself when the product's print area is drawn, its print file over the design" do
    product = Printify::Import.new.call("pf-tee")
    product.update!(print_area: { "x" => 0.25, "y" => 0.2, "w" => 0.5, "h" => 0.6, "position" => "front" },
      buyer_inputs: [ { "label" => "Name", "required" => "1", "preview" => { "x" => 0.3, "y" => 0.5, "w" => 0.4, "h" => 0.1, "font" => "Pacifico", "color" => "#ff0000" } } ])
    order = place_order(product.variant_for(%w[ Black S ]), status: "pending")
    item = order.line_items.sole.tap { |line| line.update!(properties: { "name" => "Ada" }) }
    assert_not Printify::Fulfillment.new(order).needs_personalizing?

    perform_enqueued_jobs(only: Order::FulfillJob) { order.mark_paid! }
    line = @printify.orders.sole[:line_items].sole
    assert_equal [ 6, 99, 1001, 1 ], line.values_at(:blueprint_id, :print_provider_id, :variant_id, :quantity)
    assert_equal [ "https://images.example/designs/design-1.png", "https://images.example/uploads/#{order.number}-#{item.id}-front.png" ], line[:print_areas]["front"].pluck(:src)
    assert_equal({ src: "https://images.example/back-design.png", x: 0.5, y: 0.3, scale: 0.5, angle: 0 }, line[:print_areas]["back"].sole)
    assert_equal({ x: 0.5, y: 0.5, scale: 1, angle: 0 }, line[:print_areas]["front"].last.except(:src))
    assert_equal [ "front", "back" ], line[:print_areas].keys, "Printify's own neck label isn't a design to send"

    print_file = Vips::Image.new_from_buffer(@printify.uploads.sole[:data], "")
    assert_equal [ 300, 400, 4 ], [ print_file.width, print_file.height, print_file.bands ]
    assert item.reload.print_file.attached?
    assert order.reload.printify_order_id.present?
  end

  test "a personalized order whose design is text made in Printify's editor waits, saying why" do
    product = Printify::Import.new.call("pf-tee")
    @printify.product_data["print_areas"].first["placeholders"].first["images"] = [ { "id" => "t-1", "layerType" => "text", "input_text" => "SARCASM", "x" => 0.5, "y" => 0.2, "scale" => 0.8 } ]
    product.update!(print_area: { "x" => 0.25, "y" => 0.2, "w" => 0.5, "h" => 0.6 },
      buyer_inputs: [ { "label" => "Name", "preview" => { "x" => 0.3, "y" => 0.5, "w" => 0.4, "h" => 0.1, "font" => "Lora" } } ])
    order = place_order(product.variant_for(%w[ Black S ]), status: "pending")
    order.line_items.sole.update!(properties: { "name" => "Ada" })

    perform_enqueued_jobs(only: Order::FulfillJob) { order.mark_paid! }
    assert_empty @printify.orders
    assert_match "text made there (\"SARCASM\")", order.reload.fulfillment_error
  end

  test "staff can send an order with text the buyer typed as it is" do
    product = Printify::Import.new.call("pf-tee")
    order = place_order(product.variant_for(%w[ White S ]))
    order.line_items.sole.update!(properties: { "gift_note" => "Happy birthday" })

    Printify::Fulfillment.new(order).submit!
    assert_empty @printify.orders

    Printify::Fulfillment.new(order).submit!(personalized: false)
    assert_equal [ { product_id: "pf-tee", variant_id: 1003, quantity: 1 } ], @printify.orders.sole[:line_items]
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
