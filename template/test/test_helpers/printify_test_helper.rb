# Printify without the network: `printify = connect_fake_printify` connects the shop to a
# FakePrintifyGateway with one t-shirt (Black and White, S and M; White M isn't made) and records
# the orders the app sends.
class FakePrintifyGateway
  attr_reader :sent_to_production, :deleted_webhooks, :cancelled
  attr_accessor :error, :shipments, :product_data, :shop_list, :status, :existing_webhooks, :fail_webhook_after, :existing_orders

  SHOP = { "id" => 4242, "title" => "Fake Printify shop", "sales_channel" => "custom_integration" }.freeze

  def initialize
    @orders, @sent_to_production, @shipments, @shop_list, @webhooks, @deleted_webhooks, @cancelled = [], [], [], [ SHOP ], [], [], []
    @product_data = {
      "id" => "pf-tee", "title" => "Sunset Tee", "description" => "<p>Soft cotton.</p><p>Printed to order.</p>",
      "options" => [
        { "name" => "Colors", "type" => "color", "values" => [ { "id" => 521, "title" => "Black", "colors" => [ "#000000" ] }, { "id" => 522, "title" => "White", "colors" => [ "#ffffff" ] }, { "id" => 523, "title" => "Red" } ] },
        { "name" => "Sizes", "type" => "size", "values" => [ { "id" => 14, "title" => "S" }, { "id" => 15, "title" => "M" } ] }
      ],
      "variants" => [
        { "id" => 1001, "sku" => "PF-BLK-S", "price" => 2500, "cost" => 1150, "is_enabled" => true, "is_available" => true, "options" => [ 521, 14 ] },
        { "id" => 1002, "sku" => "PF-BLK-M", "price" => 2500, "cost" => 1150, "is_enabled" => true, "is_available" => true, "options" => [ 521, 15 ] },
        { "id" => 1003, "sku" => "PF-WHT-S", "price" => 2700, "cost" => 1200, "is_enabled" => true, "is_available" => true, "options" => [ 522, 14 ] },
        { "id" => 1004, "sku" => "PF-WHT-M", "price" => 2700, "cost" => 1200, "is_enabled" => false, "is_available" => true, "options" => [ 522, 15 ] },
        { "id" => 1005, "sku" => "PF-RED-S", "price" => 2500, "cost" => 1150, "is_enabled" => false, "is_available" => true, "options" => [ 523, 14 ] }
      ],
      "images" => [
        { "src" => "https://images.example/black-front.jpg", "variant_ids" => [ 1001, 1002 ], "position" => "front", "is_default" => true },
        { "src" => "https://images.example/white-front.jpg", "variant_ids" => [ 1003, 1004 ], "position" => "front", "is_default" => false },
        { "src" => "https://images.example/black-back.jpg", "variant_ids" => [ 1001, 1002 ], "position" => "back", "is_default" => false }
      ]
    }
  end

  def shops = fail_or(shop_list)
  def products(_shop_id, page: 1) = fail_or({ "data" => [ product_data ], "last_page" => 1 })
  def product(_shop_id, _id) = fail_or(product_data)

  def create_order(shop_id, order)
    fail_or(nil)
    if Array(existing_orders).any? { |existing| existing.dig("metadata", "shop_order_id") == order[:external_id] }
      raise PrintifyGateway::Error, "Operation failed.: Order already exists for the given external_id."
    end
    @orders << order.merge(shop_id:)
    "pf-order-#{@orders.size}"
  end

  # Called with a shop id: what Printify has (existing_orders); without: those the app sent.
  def orders(shop_id = nil, page: 1) = shop_id ? fail_or({ "data" => Array(existing_orders), "last_page" => 1 }) : @orders

  def send_to_production(_shop_id, order_id) = fail_or(@sent_to_production << order_id)
  def cancel_order(_shop_id, order_id) = fail_or(@cancelled << order_id)
  def order(_shop_id, id) = fail_or({ "id" => id, "status" => status || (shipments.any? ? "fulfilled" : "in-production"), "shipments" => shipments })


  # Called with a shop id: what Printify has (existing_webhooks); without: those the app created.
  def webhooks(shop_id = nil) = shop_id ? fail_or(Array(existing_webhooks)) : @webhooks

  def create_webhook(shop_id, topic:, url:, secret:)
    raise PrintifyGateway::Error, "Printify answered 500" if fail_webhook_after && @webhooks.size >= fail_webhook_after
    fail_or(@webhooks << { shop_id:, topic:, url:, secret: })
    "wh-#{@webhooks.size}"
  end

  def delete_webhook(_shop_id, id, host:) = fail_or(@deleted_webhooks << [ id, host ])
  def download(_url) = fail_or(StringIO.new(Rails.root.join("test/fixtures/files/product.png").binread))

  private
    def fail_or(value)
      raise PrintifyGateway::Error, error if error
      value
    end
end

module PrintifyTestHelper
  def connect_fake_printify(gateway = FakePrintifyGateway.new, shop: true)
    PrintifyGateway.define_singleton_method(:build) { |_token| gateway }
    Store.current.update!(printify_token: "fake-token", printify_shop_id: (FakePrintifyGateway::SHOP["id"].to_s if shop), printify_shop_title: ("Fake Printify shop" if shop))
    gateway
  end

  def after_teardown
    PrintifyGateway.define_singleton_method(:build) { |token| new(token) }
    super
  end
end

ActiveSupport.on_load(:active_support_test_case) { include PrintifyTestHelper }
