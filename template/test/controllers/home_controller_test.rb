require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "visitors see the home page without signing in" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_session_path
  end

  test "a signed-in customer sees their name instead of sign in" do
    sign_in_as_customer customers(:casey)

    get root_path
    assert_select "a[href=?]", account_path, text: /Casey Customer/
  end

  test "signed-in staff are a visitor here, not a customer" do
    sign_in_as users(:owner)

    get root_path
    assert_select "a[href=?]", new_session_path
  end
end
