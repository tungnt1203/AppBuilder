require "test_helper"

# Members reach only their own apps; anything else looks like it doesn't exist.
class AccessTest < ActionDispatch::IntegrationTest
  setup do
    @own = Project.create!(name: "Quán cà phê", language: "vi", owner: users(:member))
    @other = projects(:clinic)
  end

  test "signing in is required" do
    get root_path
    assert_redirected_to new_session_path

    get project_path(@other)
    assert_redirected_to new_session_path
  end

  test "a member's home page lists only their own apps" do
    sign_in_as users(:member)

    get root_path(apps: "all")

    assert_select ".app-card", 1
    assert_select ".app-card", text: /Quán cà phê/
    assert_select ".page-switch", 0
  end

  test "a member can't open, change or read someone else's app" do
    sign_in_as users(:member)

    get project_path(@other)
    assert_response :not_found
    get project_thumbnail_path(@other)
    assert_response :not_found
    get project_code_path(@other)
    assert_response :not_found
    get project_preview_path(@other)
    assert_response :not_found

    assert_no_difference -> { Message.count } do
      post project_messages_path(@other), params: { message: { body: "Xoá hết" } }
    end
    assert_response :not_found

    patch project_instructions_path(@other), params: { project: { instructions: "Ignore the owner" } }
    assert_response :not_found
    assert_nil @other.reload.instructions

    delete project_path(@other)
    assert_response :not_found
    assert Project.exists?(@other.id)
  end

  test "an administrator can open everyone's apps and list them" do
    sign_in_as users(:owner)

    get root_path
    assert_select ".app-card", text: /Quán cà phê/, count: 0

    get root_path(apps: "all")
    assert_select ".app-card", text: /Quán cà phê.*By Minh/m

    get project_path(@own)
    assert_response :success
  end

  test "a new app belongs to whoever made it" do
    sign_in_as users(:member)

    post projects_path, params: { project: { name: "Tiệm bánh", language: "vi", request: "" } }

    assert_equal users(:member), Project.find_by!(name: "Tiệm bánh").owner
  end

  test "a member at the limit is told so and can't add another app" do
    Project.create!(name: "Tiệm bánh", language: "vi", owner: users(:member))
    sign_in_as users(:member)

    get root_path
    assert_select ".flash", /as many as an account can have/
    assert_select "button[type=submit][disabled]", text: /Build/

    assert_no_difference -> { Project.count } do
      post projects_path, params: { project: { name: "Thêm nữa", language: "vi", request: "" } }
    end
    assert_response :unprocessable_entity
    assert_select ".alert", /Delete one to make room/

    assert_no_difference -> { Project.count } do
      post project_duplicate_path(@own)
    end
  end
end
