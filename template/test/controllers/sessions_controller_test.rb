require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { enable_customer_accounts }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "a customer signs in and goes back to the page they wanted" do
    get account_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: "casey@example.com", password: "password" }

    assert_redirected_to account_url
    assert cookies[:customer_session_id].present?
  end

  test "wrong password" do
    post session_path, params: { email_address: "casey@example.com", password: "wrong" }

    assert_redirected_to new_session_path(email_address: "casey@example.com")
    assert_nil cookies[:customer_session_id]
  end

  test "staff accounts can't sign in here" do
    post session_path, params: { email_address: users(:owner).email_address, password: "password" }

    assert_nil cookies[:customer_session_id]
    assert_nil cookies[:admin_session_id]
  end

  test "sign out" do
    sign_in_as_customer customers(:casey)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:customer_session_id]
  end
end
