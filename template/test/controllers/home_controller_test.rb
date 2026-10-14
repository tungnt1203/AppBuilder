require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "visitors see the home page without signing in" do
    get root_path
    assert_response :success
  end

  test "a shop without products says they're coming, and only the preview tells the owner how to add them" do
    Product.update_all(status: "draft")

    get root_path
    assert_select "p", "Our first products are on their way. Check back soon."
    assert_no_match "Import from Printify", response.body, "visitors of the real shop never see the owner's hint"

    get products_path
    assert_select "p", "Our first products are on their way. Check back soon."
  end

  test "older phones and in-app browsers get the site" do
    [ "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/19H12 [FBAN/FBIOS;FBAV/430.0.0.0;FBSV/15.7]",
      "Mozilla/5.0 (Linux; Android 12; SM-A125F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36" ].each do |agent|
      get root_path, headers: { "User-Agent" => agent }
      assert_response :success, agent
      get product_path(products(:tee)), headers: { "User-Agent" => agent }
      assert_response :success, agent
    end
  end

  test "without customer accounts there's no sign in, and the account pages don't exist" do
    get root_path
    assert_select "a[href=?]", new_session_path, count: 0

    [ new_session_path, new_registration_path, new_password_path, account_path ].each do |path|
      get path
      assert_response :not_found
    end
  end

  test "with customer accounts the header offers sign in" do
    enable_customer_accounts

    get root_path
    assert_select "a[href=?]", new_session_path
  end

  test "a signed-in customer sees their name instead of sign in" do
    enable_customer_accounts
    sign_in_as_customer customers(:casey)

    get root_path
    assert_select "a[href=?]", account_path, text: /Casey Customer/
  end

  test "signed-in staff are a visitor here, not a customer" do
    enable_customer_accounts
    sign_in_as users(:owner)

    get root_path
    assert_select "a[href=?]", new_session_path
  end
end
