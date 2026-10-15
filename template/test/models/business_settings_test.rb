require "test_helper"

class BusinessSettingsTest < ActiveSupport::TestCase
  setup do
    @stripe = connect_fake_stripe
    Store.current.update!(stripe_secret_key: nil, stripe_account_name: nil)
    @printify = connect_fake_printify(shop: false)
    Store.current.update!(printify_token: nil)
    @settings = BusinessSettings.new(base_url: "https://cats.example.com")
  end

  test "connects Stripe and Printify, registers their webhooks, and sets the pixels" do
    result = @settings.apply!("stripe_secret_key" => "sk_test_abc", "printify_token" => "pf-token",
      "printify_shop_id" => FakePrintifyGateway::SHOP["id"].to_s, "meta_pixel_id" => "123456789012345", "meta_access_token" => "EAAtesttoken1234567890", "tiktok_pixel_id" => "")

    store = Store.current.reload
    assert_empty result["errors"]
    assert_equal "sk_test_abc", store.stripe_secret_key
    assert_equal "https://cats.example.com/stripe/webhook", store.stripe_webhook_url
    assert_equal [ FakePrintifyGateway::SHOP["id"].to_s, "Fake Printify shop" ], [ store.printify_shop_id, store.printify_shop_title ]
    assert_equal "https://cats.example.com/printify/webhook", store.printify_webhook_url
    assert_equal [ "123456789012345", "EAAtesttoken1234567890", nil ], [ store.meta_pixel_id, store.meta_access_token, store.tiktok_pixel_id ]
    assert_equal "Fake Printify shop", result["printify"]
    assert_equal "meta pixel", result["pixels"]
  end

  test "the same settings again change nothing, and a blank one disconnects" do
    @settings.apply!("stripe_secret_key" => "sk_test_abc")
    webhook = Store.current.reload.stripe_webhook_id
    @settings.apply!("stripe_secret_key" => "sk_test_abc")
    assert_equal webhook, Store.current.reload.stripe_webhook_id, "not reconnected"

    assert_equal "not connected", @settings.apply!("stripe_secret_key" => "")["stripe"]
    assert_not Store.current.reload.stripe_connected?
  end

  test "a key Stripe refuses is reported, and the rest still applies" do
    @stripe.error = "Invalid API Key"
    result = @settings.apply!("stripe_secret_key" => "sk_test_bad", "google_tag_id" => "G-TEST1234")

    assert_match "Stripe: Invalid API Key", result["errors"].sole
    assert_equal "G-TEST1234", Store.current.reload.google_tag_id
  end
end
