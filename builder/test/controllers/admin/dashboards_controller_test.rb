require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:member) }

  test "shows the last 30 days and the latest orders of all the shops someone runs" do
    in_shop(shops(:cats))
    paid = orders(:paid)
    ActsAsTenant.current_tenant = nil

    get admin_root_path
    assert_select "h1", "Orders"
    assert_select "li", /Orders\s*\d+/
    assert_select "a[href=?]", shop_admin_order_path(shops(:cats), paid.token), /#1002\s+#{paid.shipping_name}/
    assert_select "a[href=?]", shop_admin_root_path(shops(:cats)), "Chubby Cat Tees"
    assert_select "a[href=?]", shop_admin_root_path(shops(:dogs)), "Good Boy Hoodies"
    assert_select "aside[aria-label=Admin] a", text: "Accounts", count: 0 # not an administrator of the builder
  end

  test "staff see their shops only" do
    sign_in_as users(:cats_staff)
    get admin_root_path
    assert_select "a[href=?]", shop_admin_root_path(shops(:dogs)), count: 0
  end

  test "someone who doesn't run a shop yet is asked to open one" do
    sign_in_as users(:owner)
    get admin_root_path
    assert_select "a[href=?]", new_admin_shop_path, "Open one"
    assert_select "aside[aria-label=Admin] a", "Accounts"
    get admin_users_path
    assert_response :success
  end
end
