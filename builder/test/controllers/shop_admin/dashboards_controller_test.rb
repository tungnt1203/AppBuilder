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

  test "a shop without products shows its owner the first steps, people included" do
    Product.destroy_all
    sign_in_as users(:member)

    get shop_admin_root_path
    assert_response :success
    assert_select "ol a[href=?]", shop_admin_memberships_path
    assert_select "ol a[href=?]", shop_admin_printify_connection_path

    sign_in_as users(:cats_staff)
    get shop_admin_root_path
    assert_select "ol a[href=?]", shop_admin_memberships_path, count: 0
  end
end
