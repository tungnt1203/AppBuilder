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

    post open_project_chat_path(@project, earlier)

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

  test "a chat is renamed in place" do
    patch project_chat_path(@project, chats(:clinic)), params: { chat: { title: "  Lịch hẹn   và nhắc lịch " } }

    assert_redirected_to @project
    assert_equal "Lịch hẹn và nhắc lịch", chats(:clinic).reload.title
  end

  test "deleting the current chat goes to the latest other one" do
    earlier = @project.current_chat
    later = @project.start_chat
    later.messages.create!(role: :user, body: "Thêm trang giá")

    assert_difference -> { Message.count }, -1 do
      delete project_chat_path(@project, later)
    end

    assert_redirected_to @project
    assert_equal earlier, @project.reload.current_chat
  end

  test "deleting the only chat leaves a new one" do
    delete project_chat_path(@project, chats(:clinic))

    @project.reload
    assert_equal 1, @project.chats.count
    assert_empty @project.messages
    assert_nil @project.session_id
  end

  test "deleting an earlier chat keeps the current one" do
    earlier = @project.current_chat
    current = @project.start_chat

    delete project_chat_path(@project, earlier)

    assert_equal current, @project.reload.current_chat
    assert_not Chat.exists?(earlier.id)
  end

  test "chats aren't deleted while the agent works" do
    @project.update!(status: :working)

    assert_no_difference -> { Chat.count } do
      delete project_chat_path(@project, chats(:clinic))
    end
  end

  test "the menu offers to rename and delete each chat" do
    get project_path(@project)

    assert_select ".chat-row", 1
    assert_select ".chat-row-rename input[name='chat[title]'][value='Làm app đặt lịch']"
    assert_select ".chat-row-confirm form[action='#{project_chat_path(@project, chats(:clinic))}']"
  end
end
