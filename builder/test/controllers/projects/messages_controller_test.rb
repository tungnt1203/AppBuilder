require "test_helper"

class Projects::MessagesControllerTest < ActionDispatch::IntegrationTest
  test "sends a request to the agent" do
    project = projects(:clinic)

    assert_enqueued_with(job: AgentTurnJob, args: [ project, "Thêm trang báo cáo" ]) do
      post project_messages_path(project), params: { message: { body: "Thêm trang báo cáo" } }
    end

    assert project.reload.working?
    assert_equal "Thêm trang báo cáo", project.messages.last.body
  end

  test "waits while the agent is working" do
    assert_no_enqueued_jobs do
      post project_messages_path(projects(:shop)), params: { message: { body: "Another change" } }
    end
  end
end
