require "test_helper"

class MetaPurchaseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  ADDRESS = { email: "Robin@Example.com", phone: "+1 (512) 555-0100", shipping_name: "Robin  Q Buyer", shipping_address1: "5 Elm St",
    shipping_city: "San Antonio", shipping_region: "TX", shipping_postal_code: "78701-1234", shipping_country: "US" }.freeze

  setup { @meta = connect_fake_meta }

  test "a manual order goes to Meta when placed, as the pixel's purchase, with the buyer hashed" do
    order = place(attribution: { "fbp" => "fb.1.1700000000000.42", "fbc" => "fb.1.1700000000000.abc", "ip" => "203.0.113.9",
      "user_agent" => "Mozilla/5.0", "url" => "https://shop.example/checkout/new" })
    perform_enqueued_jobs

    event = @meta.events.sole
    assert_equal [ "Purchase", "purchase-#{order.number}", "website", "https://shop.example/checkout/new" ],
      event.values_at(:event_name, :event_id, :action_source, :event_source_url)
    assert_equal({ currency: "USD", value: order.total_cents / 100.0, order_id: order.number.to_s, content_type: "product",
      content_ids: [ "TEE-BLK-S" ], contents: [ { id: "TEE-BLK-S", quantity: 2, item_price: 24.0 } ], num_items: 2 }, event[:custom_data])

    user = event[:user_data]
    assert_equal [ sha("robin@example.com") ], user[:em]
    assert_equal [ sha("15125550100") ], user[:ph]
    assert_equal [ [ sha("robin") ], [ sha("q buyer") ], [ sha("sanantonio") ], [ sha("tx") ], [ sha("78701") ], [ sha("us") ] ],
      user.values_at(:fn, :ln, :ct, :st, :zp, :country)
    assert_equal [ "fb.1.1700000000000.42", "fb.1.1700000000000.abc", "203.0.113.9", "Mozilla/5.0" ],
      user.values_at(:fbp, :fbc, :client_ip_address, :client_user_agent)

    assert order.reload.purchase_reported_at
    assert_equal "123456789012345", @meta.sent.sole[:pixel_id]
  end

  test "a card order goes once it's paid, and only once" do
    connect_fake_stripe
    order = place(payment_method: "stripe")
    perform_enqueued_jobs
    assert_empty @meta.events

    order.confirm_card_payment!(payment_intent: "pi_1")
    perform_enqueued_jobs
    Meta::Purchase.new(order.reload).report!
    assert_equal [ "purchase-#{order.number}" ], @meta.events.map { _1[:event_id] }
  end

  test "test events carry the owner's test code" do
    Store.current.update!(meta_test_event_code: "TEST123")
    place
    perform_enqueued_jobs
    assert_equal "TEST123", @meta.sent.sole[:test_event_code]
  end

  test "nothing goes to Meta without an access token" do
    Store.current.update!(meta_access_token: nil)
    assert_no_enqueued_jobs(only: Order::ReportPurchaseJob) { place }
  end

  test "Meta being down is tried again; a refused token stops and shows in settings" do
    order = place
    @meta.error = MetaGateway::Error.new("Meta answered 500")
    assert_enqueued_with(job: Order::ReportPurchaseJob) { perform_enqueued_jobs(only: Order::ReportPurchaseJob) }
    assert_nil order.reload.purchase_reported_at

    clear_enqueued_jobs
    Order::ReportPurchaseJob.perform_later(order)
    @meta.error = MetaGateway::TokenError.new("Meta didn't accept the access token.")
    perform_enqueued_jobs(only: Order::ReportPurchaseJob)
    assert_no_enqueued_jobs(only: Order::ReportPurchaseJob)
    assert_equal "Meta didn't accept the access token.", Store.current.meta_error

    Store.current.update!(meta_access_token: "EAAnewtoken12345678901")
    assert_nil Store.current.meta_error
  end

  test "the access token is stored encrypted" do
    raw = Store.connection.select_value("SELECT meta_access_token FROM stores WHERE id = #{Store.current.id}")
    assert_not_includes raw, "EAAfaketoken"
  end

  private
    def place(payment_method: "manual", attribution: nil)
      cart = Cart.create!
      cart.items.create!(variant: variants(:tee_black_s), quantity: 2)
      checkout = Checkout.new(cart:, **ADDRESS, payment_method:)
      checkout.attribution = attribution
      checkout.place or flunk(checkout.errors.full_messages.to_sentence)
    end

    def sha(value) = OpenSSL::Digest::SHA256.hexdigest(value)
end
