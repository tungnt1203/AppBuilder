require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:member)
    @shops = [ { "id" => 11, "title" => "Cat shop" } ]
    shops = @shops
    PrintifyAccount.singleton_class.alias_method(:original_shops, :shops)
    PrintifyAccount.define_singleton_method(:shops) { |_token| shops }
  end

  teardown do
    PrintifyAccount.singleton_class.alias_method(:shops, :original_shops)
  end

  test "saves the settings once, picks the only Printify shop, and applies them to every shop" do
    get admin_settings_path
    assert_select "h1", "Settings"

    assert_enqueued_jobs 2, only: BusinessSyncJob do
      patch admin_settings_path, params: { business_setting: { stripe_secret_key: "sk_test_abc", printify_token: "pf-token", meta_pixel_id: "123456789012" } }
    end
    assert_redirected_to admin_settings_path

    setting = users(:member).business_setting
    assert_equal [ "sk_test_abc", "pf-token", "11", "Cat shop" ], setting.values_at(:stripe_secret_key, :printify_token, :printify_shop_id, :printify_shop_title)
    follow_redirect!
    assert_select "span.font-mono", "sk_test_…_abc"
    assert_no_match "sk_test_abc", response.body, "the key isn't shown again"
  end

  test "goes to the shops they own or administer, and shows what each got" do
    sign_in_as users(:cats_staff)
    patch admin_settings_path, params: { business_setting: { meta_pixel_id: "123456789012" } }
    assert_no_enqueued_jobs only: BusinessSyncJob

    sign_in_as users(:cats_admin)
    shops(:cats).update!(business_synced_at: 1.minute.ago, business_sync_result: { "stripe" => "Acme (test mode)", "errors" => [ "Printify: no such shop" ] })
    assert_enqueued_with(job: BusinessSyncJob, args: [ shops(:cats), users(:cats_admin) ]) do
      patch admin_settings_path, params: { business_setting: { meta_pixel_id: "123456789012" } }
    end
    follow_redirect!
    assert_select "li", /Chubby Cat Tees.*Applied 1 minute ago.*Stripe: Acme \(test mode\) · Printify: no such shop/m
  end

  test "a blank secret keeps the saved one, Disconnect clears it" do
    users(:member).create_business_setting!(stripe_secret_key: "sk_test_abc", meta_access_token: "EAAtoken1234567890abc")

    patch admin_settings_path, params: { business_setting: { stripe_secret_key: "", meta_pixel_id: "123456789012" } }
    assert_equal "sk_test_abc", users(:member).business_setting.reload.stripe_secret_key

    patch admin_settings_path, params: { business_setting: { clear_stripe_secret_key: "1", clear_meta_access_token: "1" } }
    assert_nil users(:member).business_setting.reload.stripe_secret_key
    assert_nil users(:member).business_setting.meta_access_token
  end

  test "with several Printify shops the owner picks one" do
    @shops << { "id" => 22, "title" => "Dog shop" }
    patch admin_settings_path, params: { business_setting: { printify_token: "pf-token" } }
    follow_redirect!
    assert_select "select[name='business_setting[printify_shop_id]'] option", 3

    patch admin_settings_path, params: { business_setting: { printify_shop_id: "22" } }
    assert_equal "Dog shop", users(:member).business_setting.reload.printify_shop_title
  end

  test "a wrong key is refused" do
    patch admin_settings_path, params: { business_setting: { stripe_secret_key: "pk_live_nope" } }
    assert_response :unprocessable_entity
    assert_select ".admin-alert", /should start with sk_live_ or sk_test_/
  end
end
