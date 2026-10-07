require "test_helper"

# The two halves of the app look and behave apart: the customers' site and /admin.
class LayoutTest < ActionDispatch::IntegrationTest
  test "the customers' site has the site header, not the admin sidebar" do
    User.delete_all
    get root_path

    assert_response :success
    assert_select "header a[href=?]", new_session_path
    assert_select "aside#app-nav", count: 0
    assert_select "a[href^='/admin']", count: 0
  end

  test "/admin has the sidebar and a way back to the site" do
    sign_in_as users(:owner)
    get admin_root_path

    assert_select "aside#app-nav"
    assert_select "main#main"
    assert_select "button[aria-controls=?]", "app-nav"
    assert_select "a[href=?]", root_path
    assert_select "a[href=?]", admin_users_path
  end

  test "staff without admin rights don't see the staff screen in the sidebar" do
    sign_in_as users(:staff)
    get admin_root_path

    assert_select "a[href=?]", admin_users_path, count: 0
  end
end
