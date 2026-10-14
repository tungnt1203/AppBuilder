require "test_helper"

class PrintifyWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @printify = connect_fake_printify
    Store.current.register_printify_webhooks!("https://shop.example.com/printify/webhook")
    @order = orders(:paid).tap { |order| order.update!(status: "in_production", printify_order_id: "pf-77") }
  end

  test "the shop registers a webhook for each topic, at a public address only" do
    assert_equal Store::PRINTIFY_WEBHOOK_TOPICS, @printify.webhooks.map { _1[:topic] }
    assert_equal [ "https://shop.example.com/printify/webhook" ], @printify.webhooks.map { _1[:url] }.uniq
    store = Store.current
    assert_equal [ %w[ wh-1 wh-2 wh-3 ], @printify.webhooks.first[:secret] ], [ store.printify_webhook_ids, store.printify_signing_secret ]
    assert store.printify_webhooks?("https://shop.example.com/printify/webhook")

    store.register_printify_webhooks!("http://localhost:3000/printify/webhook")
    assert_equal 3, @printify.webhooks.size

    store.register_printify_webhooks!("https://new.example.com/printify/webhook")
    assert_equal [ [ "wh-1", "shop.example.com" ], [ "wh-2", "shop.example.com" ], [ "wh-3", "shop.example.com" ] ], @printify.deleted_webhooks
    assert_equal %w[ wh-4 wh-5 wh-6 ], store.reload.printify_webhook_ids

    store.disconnect_printify!
    assert_equal 6, @printify.deleted_webhooks.size
    assert_equal [ [], nil ], store.reload.values_at(:printify_webhook_ids, :printify_webhook_secret)
  end

  test "a shipment ships the order with what Printify itself says, and emails the buyer" do
    @printify.shipments = [ { "carrier" => "usps", "number" => "9400111", "url" => "https://tools.usps.com/t/9400111" } ]

    assert_enqueued_email_with OrderMailer, :shipped, args: [ @order ] do
      deliver "order:shipment:created", "pf-77"
    end
    assert_response :ok
    assert @order.reload.shipped?
    assert_equal [ "usps", "9400111" ], [ @order.carrier, @order.tracking_number ]

    @printify.shipments = [ @printify.shipments.first.merge("delivered_at" => "2026-10-20 10:00:00+00:00") ]
    deliver "order:shipment:delivered", "pf-77"
    assert @order.reload.delivered?
  end

  test "an order Printify cancelled tells staff" do
    @printify.status = "canceled"
    deliver "order:updated", "pf-77"

    assert @order.reload.in_production?
    assert_match "Printify cancelled it", @order.fulfillment_error
    assert_equal "fulfillment_failed", @order.events.last.action
  end

  test "a forged call, an unknown order or a shop without webhooks changes nothing" do
    @printify.shipments = [ { "carrier" => "usps", "number" => "1", "url" => "https://tools.usps.com/t/1" } ]

    post printify_webhook_path, params: payload("order:shipment:created", "pf-77"), headers: { "Content-Type" => "application/json", "X-Pfy-Signature" => "sha256=forged" }
    assert_response :unauthorized
    assert @order.reload.in_production?

    deliver "order:shipment:created", "pf-unknown"
    assert_response :ok

    Store.current.update!(printify_webhook_secret: nil)
    deliver "order:shipment:created", "pf-77"
    assert_response :not_found
    assert @order.reload.in_production?
  end

  test "admins see whether Printify's updates come right away" do
    Store.current.update!(printify_webhook_ids: [], printify_webhook_url: nil)
    sign_in_as users(:admin)

    get admin_printify_connection_path
    assert_select "p", /checked every hour/
    assert_select "button", text: /right away/, count: 0

    https!
    get admin_printify_connection_path
    assert_select "button", /right away/
    patch admin_printify_connection_path(register_webhooks: 1)
    assert Store.current.printify_webhooks?("https://www.example.com/printify/webhook")
    follow_redirect!
    assert_select "p", /as soon as an order ships/
  end

  private
    def payload(type, printify_order_id)
      { id: SecureRandom.uuid, type:, created_at: Time.current.iso8601, resource: { id: printify_order_id, type: "order", data: { shop_id: 4242 } } }.to_json
    end

    def deliver(type, printify_order_id)
      body = payload(type, printify_order_id)
      signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", Store.current.printify_signing_secret.to_s, body)}"
      post printify_webhook_path, params: body, headers: { "Content-Type" => "application/json", "X-Pfy-Signature" => signature }
    end
end
