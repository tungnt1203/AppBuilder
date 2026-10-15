require "test_helper"

class BusinessSyncTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:cats)
    @setting = users(:member).create_business_setting!(stripe_secret_key: "sk_test_abc", meta_pixel_id: "123456789012")
  end

  test "secrets are encrypted, shown masked, and every key goes to the shops, blank when unset" do
    raw = BusinessSetting.connection.select_value("SELECT stripe_secret_key FROM business_settings WHERE id = #{@setting.id}")
    assert_not_includes raw, "sk_test_abc"
    assert_equal "sk_test_…_abc", BusinessSetting.masked("sk_test_abc")
    assert_equal({ "stripe_secret_key" => "sk_test_abc", "printify_token" => "", "printify_shop_id" => "", "meta_pixel_id" => "123456789012",
      "meta_access_token" => "", "tiktok_pixel_id" => "", "google_tag_id" => "" }, @setting.payload)
  end

  test "applies the settings to the shop and keeps what happened" do
    StripeGateway.define_singleton_method(:build) { |_key| FakeStripeGateway.new }
    result = BusinessSync.new(@shop, @setting).call

    assert_equal({ "errors" => [], "stripe" => "Fake Shop LLC (test mode)", "printify" => "not connected", "pixels" => "meta pixel" }, result)
    assert_equal result, @shop.reload.business_sync_result
    assert @shop.business_synced_at
    in_shop(@shop)
    assert_equal [ true, "123456789012" ], [ Store.current.stripe_connected?, Store.current.meta_pixel_id ]
    in_shop(shops(:dogs))
    assert_not Store.current.stripe_connected?, "only the shop it was applied to"
  end

  test "what Stripe or Printify refuse is kept with the rest" do
    gateway = FakeStripeGateway.new.tap { |fake| fake.error = "Invalid API Key provided" }
    StripeGateway.define_singleton_method(:build) { |_key| gateway }
    result = BusinessSync.new(@shop, @setting).call
    assert_equal [ "Stripe: Invalid API Key provided" ], result["errors"]
    assert_equal "meta pixel", result["pixels"]
  end

  test "a blank key disconnects the shop" do
    in_shop(@shop)
    connect_fake_stripe
    ActsAsTenant.current_tenant = nil
    @setting.update!(stripe_secret_key: nil)
    BusinessSync.new(@shop, @setting).call
    in_shop(@shop)
    assert_not Store.current.stripe_connected?
  end
end
