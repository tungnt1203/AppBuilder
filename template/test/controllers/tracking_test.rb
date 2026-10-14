require "test_helper"

class TrackingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ADDRESS = { email: "robin@example.com", shipping_name: "Robin Buyer", shipping_address1: "5 Elm St",
    shipping_city: "Austin", shipping_region: "TX", shipping_postal_code: "78701", shipping_country: "US" }.freeze

  test "without ad accounts the site loads no tags" do
    get product_path(products(:tee))
    assert_select "meta[name=tracking]", count: 0
    assert_select "#tracking-events", count: 0
  end

  test "with ad accounts, a purchase is tracked step by step, and once" do
    stores(:main).update!(meta_pixel_id: "123456789012345", tiktok_pixel_id: "c4abcdefghij123", google_tag_id: "g-abc1234")
    assert_equal "C4ABCDEFGHIJ123", stores(:main).tiktok_pixel_id

    get product_path(products(:tee))
    assert_select "meta[name=tracking]"
    assert_select "script", /fbq\("init", "123456789012345"\)/
    assert_equal [ "view_content" ], events.map { _1["name"] }

    post cart_items_path, params: { variant_id: variants(:tee_black_s).id, quantity: 2 }
    follow_redirect!
    add = events.sole
    assert_equal [ "add_to_cart", 48.0, "USD" ], add.values_at("name", "value", "currency")
    assert_equal [ "TEE-BLK-S", 2 ], add["items"].sole.values_at("id", "quantity")

    get new_checkout_path
    assert_equal "initiate_checkout", events.sole["name"]

    post checkout_path, params: { checkout: ADDRESS }
    order = Order.last
    follow_redirect!
    purchase = events.sole
    assert_equal [ "purchase", order.number, order.total_cents / 100.0, "purchase-#{order.number}" ], purchase.values_at("name", "order", "value", "id")

    get order_path(order, placed: 1)
    assert_empty events
  end

  test "admins connect their ad accounts in settings" do
    sign_in_as users(:admin)
    patch admin_settings_path, params: { store: { meta_pixel_id: " 123456789012345 ", google_tag_id: "G-ABC1234" } }
    assert_equal [ "123456789012345", "G-ABC1234" ], Store.current.values_at(:meta_pixel_id, :google_tag_id)

    patch admin_settings_path, params: { store: { meta_pixel_id: "not-a-pixel" } }
    assert_response :unprocessable_entity
  end

  test "a visit from a Meta ad is kept with the order, for the purchase sent from the server" do
    connect_fake_meta

    get product_path(products(:tee), fbclid: "IwAR0abc")
    assert_match(/\Afb\.1\.\d{13}\.IwAR0abc\z/, cookies[:_fbc])
    fbc = cookies[:_fbc]
    get root_path(fbclid: "IwAR0abc")
    assert_equal fbc, cookies[:_fbc]

    cookies[:_fbp] = "fb.1.1700000000000.42"
    post cart_items_path, params: { variant_id: variants(:tee_black_s).id }
    assert_enqueued_with(job: Order::ReportPurchaseJob) do
      post checkout_path, params: { checkout: ADDRESS }, headers: { "User-Agent" => "Mozilla/5.0 (iPhone)", "Referer" => "http://www.example.com/checkout/new" }
    end

    attribution = Order.last.attribution
    assert_equal [ fbc, "fb.1.1700000000000.42", "Mozilla/5.0 (iPhone)", "http://www.example.com/checkout/new" ],
      attribution.values_at("fbc", "fbp", "user_agent", "url")
    assert attribution["ip"]
  end

  test "without a Meta pixel nothing about the browser is kept" do
    get product_path(products(:tee), fbclid: "IwAR0abc")
    assert_nil cookies[:_fbc]

    post cart_items_path, params: { variant_id: variants(:tee_black_s).id }
    post checkout_path, params: { checkout: ADDRESS }
    assert_nil Order.last.attribution
  end

  test "admins add the Conversions API token; it isn't shown again and stays until removed" do
    sign_in_as users(:admin)
    patch admin_settings_path, params: { store: { meta_pixel_id: "123456789012345", meta_access_token: " EAAtoken1234567890abcdef " } }
    assert_equal "EAAtoken1234567890abcdef", Store.current.meta_access_token
    assert Store.current.meta_conversions?

    get edit_admin_settings_path
    assert_select "input[name='store[meta_access_token]']:not([value])"
    assert_no_match "EAAtoken1234567890abcdef", response.body

    patch admin_settings_path, params: { store: { meta_access_token: "", meta_test_event_code: "TEST123" } }
    assert_equal [ "EAAtoken1234567890abcdef", "TEST123" ], Store.current.values_at(:meta_access_token, :meta_test_event_code)

    patch admin_settings_path, params: { store: { meta_access_token: "" }, remove_meta_access_token: "1" }
    assert_nil Store.current.meta_access_token
  end

  private
    def events
      JSON.parse(css_select("#tracking-events").first.text)
    end
end
