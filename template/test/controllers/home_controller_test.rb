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
