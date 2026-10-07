require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "anyone can create an account, which builds only its own apps" do
    post registration_path, params: { user: { name: "Lan", email_address: "Lan@Example.com ", password: "long enough" } }

    assert_redirected_to root_path
    user = User.find_by!(email_address: "lan@example.com")
    assert user.member?
    assert cookies[:session_id]

    follow_redirect!
    assert_select ".app-card", 0
    assert_select "a[href='#{admin_users_path}']", 0
  end

  test "the first account runs the studio and takes over the apps made before accounts" do
    Session.delete_all
    Project.update_all(owner_id: nil)
    User.delete_all

    get root_path
    assert_redirected_to new_registration_path
    follow_redirect!
    assert_select "h1", "Set up your studio"

    post registration_path, params: { user: { name: "Tùng", email_address: "tung@example.com", password: "long enough" } }

    user = User.find_by!(email_address: "tung@example.com")
    assert user.owner?
    assert_equal Project.count, user.projects.count
  end

  test "tells what's wrong with the account" do
    post registration_path, params: { user: { name: "", email_address: "owner@example.com", password: "short" } }

    assert_response :unprocessable_entity
    assert_select ".alert", /Name can't be blank.*Email address has already been taken.*Password is too short/
  end
end
