require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "needs a signed-in customer" do
    get account_path
    assert_redirected_to new_session_path
  end

  test "signed-in staff are not customers" do
    sign_in_as users(:owner)

    get account_path
    assert_redirected_to new_session_path
  end

  test "shows the customer's own account" do
    sign_in_as_customer customers(:casey)

    get account_path
    assert_response :success
    assert_select "h1", "Casey Customer"
  end

  test "changes name without a password" do
    sign_in_as_customer customers(:casey)

    patch account_path, params: { customer: { name: "Casey C.", email_address: "casey@example.com", password: "", password_challenge: "" } }

    assert_redirected_to account_path
    assert_equal "Casey C.", customers(:casey).reload.name
  end

  test "a new password needs the current one" do
    sign_in_as_customer customers(:casey)

    patch account_path, params: { customer: { name: "Casey", email_address: "casey@example.com", password: "brand new pass", password_challenge: "wrong" } }
    assert_response :unprocessable_entity

    patch account_path, params: { customer: { name: "Casey", email_address: "casey@example.com", password: "brand new pass", password_challenge: "password" } }
    assert_redirected_to account_path
    assert customers(:casey).reload.authenticate("brand new pass")
  end
end
