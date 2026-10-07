require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup { enable_customer_accounts }

  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "a visitor creates an account and is signed in" do
    assert_difference -> { Customer.count } do
      post registration_path, params: { customer: { name: "Riley", email_address: "riley@example.com", password: "longenough" } }
    end

    assert_redirected_to account_url
    assert cookies[:customer_session_id].present?
  end

  test "mistakes show the form again" do
    assert_no_difference -> { Customer.count } do
      post registration_path, params: { customer: { name: "", email_address: "casey@example.com", password: "short" } }
    end

    assert_response :unprocessable_entity
  end

  test "creating an account never creates a staff account" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { customer: { name: "Riley", email_address: "riley@example.com", password: "longenough", role: "owner" } }
    end
  end
end
