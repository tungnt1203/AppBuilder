require "test_helper"

class ShopAdmin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }

  test "requires a staff sign in" do
    get shop_admin_root_path
    assert_redirected_to new_session_path(shop_id: nil)
  end

  test "shows the dashboard to staff" do
    sign_in_as users(:cats_staff)

    get shop_admin_root_path
    assert_response :success
    assert_select "h1", I18n.t("shop_admin.dashboards.show.title")
    assert_select "p", /Sam Staff/
  end

  test "until the shop can sell, the dashboard ticks what's done and links each step left" do
    store = stores(:cats).tap { |cats| cats.update!(payment_instructions: "", stripe_secret_key: nil, stripe_publishable_key: nil, refund_policy: "", shipping_policy: "", privacy_policy: "") }
    sign_in_as users(:member)

    get shop_admin_root_path
    assert_select "li", text: /A product is on sale/
    assert_select "a[href=?]", edit_shop_admin_settings_path(anchor: "payments"), /Take payments/
    assert_select "a[href=?]", edit_shop_admin_policies_path, /Publish your refund/
    assert_select "a[href=?]", shop_admin_printify_connection_path

    sign_in_as users(:cats_staff)
    get shop_admin_root_path
    assert_select "a[href=?]", edit_shop_admin_policies_path, { count: 0 }, "staff do not change settings"

    store.update!(payment_instructions: "Bank transfer to 123", refund_policy: "30 days", shipping_policy: "3 days", privacy_policy: "We keep your email")
    get shop_admin_root_path
    assert_select "h2", text: /Get your shop ready/, count: 0
  end
end
