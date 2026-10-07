require "test_helper"

class Admin::FirstRunsControllerTest < ActionDispatch::IntegrationTest
  test "a new app sends whoever opens /admin to create the owner account" do
    User.delete_all

    get admin_root_path
    assert_redirected_to new_admin_first_run_path

    get new_admin_session_path
    assert_redirected_to new_admin_first_run_path
  end

  test "the customers' site never sends visitors to the first-run setup" do
    User.delete_all

    get root_path
    assert_response :success
  end

  test "creating the first account makes it the owner and signs in" do
    User.delete_all

    post admin_first_run_path, params: { user: { name: "Founder", email_address: "founder@example.com", password: "secret123" } }

    assert_redirected_to admin_root_path
    assert User.find_by(email_address: "founder@example.com").owner?
    assert cookies[:admin_session_id].present?
  end

  test "invalid details show the form again" do
    User.delete_all

    post admin_first_run_path, params: { user: { name: "", email_address: "founder@example.com", password: "secret123" } }

    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end

  test "first run is closed once an account exists" do
    get new_admin_first_run_path
    assert_redirected_to admin_root_path

    assert_no_difference -> { User.count } do
      post admin_first_run_path, params: { user: { name: "Intruder", email_address: "x@example.com", password: "secret123" } }
    end
  end
end
