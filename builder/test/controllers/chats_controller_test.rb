require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:owner)
    @project = projects(:clinic)
  end

  test "a new chat starts without a session, and the earlier one stays in the list" do
    earlier = @project.current_chat

    post project_chats_path(@project)

    assert_redirected_to @project
    @project.reload
    assert_not_equal earlier, @project.current_chat
    assert_nil @project.session_id
    assert_empty @project.messages

    get project_path(@project)
    assert_select ".chat-empty"
    assert_select ".chat-list button.chat-link", text: /Làm app đặt lịch/
  end

  test "a chat nothing was said in yet isn't started again" do
    post project_chats_path(@project)

    assert_no_difference -> { @project.chats.count } do
      post project_chats_path(@project)
    end
  end

  test "going back to an earlier chat resumes its session" do
    earlier = @project.current_chat
    @project.start_chat

    patch project_chat_path(@project, earlier)

    assert_equal earlier, @project.reload.current_chat
    assert_equal "session-123", @project.session_id
  end

  test "chats don't change while the agent works" do
    @project.update!(status: :working)

    assert_no_difference -> { @project.chats.count } do
      post project_chats_path(@project)
    end
  end

  test "another account's app has no chats to open" do
    sign_in_as users(:member)

    post project_chats_path(@project)

    assert_response :not_found
  end
end
