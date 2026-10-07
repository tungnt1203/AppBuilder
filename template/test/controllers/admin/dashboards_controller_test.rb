require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "requires a staff sign in" do
    get admin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "a signed-in customer is not let in" do
    sign_in_as_customer customers(:casey)

    get admin_root_path
    assert_redirected_to new_admin_session_path
  end

  test "shows the dashboard to staff" do
    sign_in_as users(:staff)

    get admin_root_path
    assert_response :success
    assert_select "h1", /Sam Staff/
  end
end
