require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows the home screen" do
    sign_in_as users(:member)

    get root_path
    assert_response :success
    assert_select "h1", /Mia Member/
  end
end
