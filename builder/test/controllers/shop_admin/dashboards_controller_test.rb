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
end
