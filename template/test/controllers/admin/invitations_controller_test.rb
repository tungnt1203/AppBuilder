require "test_helper"

class Admin::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.invite(name: "Invited Person", email_address: "invited@example.com")
    @token = @user.generate_token_for(:invitation)
  end

  test "show asks the invited user to choose a password" do
    get admin_invitation_path(@token)
    assert_response :success
    assert_select "h1", /Invited Person/
  end

  test "choosing a password signs the user in and uses up the link" do
    put admin_invitation_path(@token), params: { user: { password: "secret123" } }

    assert_redirected_to admin_root_path
    assert @user.reload.authenticate("secret123")

    get admin_invitation_path(@token)
    assert_redirected_to new_admin_session_path
  end

  test "an invalid link is rejected" do
    get admin_invitation_path("not-a-token")
    assert_redirected_to new_admin_session_path
  end
end
