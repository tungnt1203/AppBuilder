require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.invite(name: "Invited Person", email_address: "invited@example.com")
    @token = @user.generate_token_for(:invitation)
  end

  test "show asks the invited user to choose a password" do
    get invitation_path(@token)
    assert_response :success
    assert_select "h1", /Invited Person/
  end

  test "choosing a password signs the user in and uses up the link" do
    put invitation_path(@token), params: { user: { password: "secret123" } }

    assert_redirected_to root_path
    assert @user.reload.authenticate("secret123")

    get invitation_path(@token)
    assert_redirected_to new_session_path
  end

  test "an invalid link is rejected" do
    get invitation_path("not-a-token")
    assert_redirected_to new_session_path
  end
end
