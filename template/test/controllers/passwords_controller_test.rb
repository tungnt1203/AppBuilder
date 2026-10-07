require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { enable_customer_accounts }

  setup { @customer = customers(:casey) }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create emails a customer" do
    post passwords_path, params: { email_address: @customer.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @customer ]
    assert_redirected_to new_session_path
  end

  test "create for a staff email sends nothing" do
    post passwords_path, params: { email_address: users(:owner).email_address }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path
  end

  test "update sets the new password and signs out everywhere" do
    sign_in_as_customer @customer

    put password_path(@customer.password_reset_token), params: { password: "brand new pass", password_confirmation: "brand new pass" }

    assert_redirected_to new_session_path
    assert @customer.reload.authenticate("brand new pass")
    assert_empty @customer.sessions
  end

  test "update with non matching passwords" do
    token = @customer.password_reset_token
    assert_no_changes -> { @customer.reload.password_digest } do
      put password_path(token), params: { password: "brand new pass", password_confirmation: "other pass" }
      assert_redirected_to edit_password_path(token)
    end
  end

  test "an invalid link" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path
  end
end
