require "test_helper"

class Projects::MessagesControllerTest < ActionDispatch::IntegrationTest
  test "sends a request to the agent" do
    project = projects(:clinic)

    assert_enqueued_with(job: AgentTurnJob, args: [ project, "Thêm trang báo cáo", "build" ]) do
      post project_messages_path(project), params: { message: { body: "Thêm trang báo cáo", plan: "0" } }
    end

    assert project.reload.working?
    assert_equal "Thêm trang báo cáo", project.messages.last.body
  end

  test "asks for a plan first when Plan first is on" do
    assert_enqueued_with(job: AgentTurnJob, args: [ projects(:clinic), "Làm trang báo cáo", "plan" ]) do
      post project_messages_path(projects(:clinic)), params: { message: { body: "Làm trang báo cáo", plan: "1" } }
    end
  end

  test "waits while the agent is working" do
    assert_no_enqueued_jobs do
      post project_messages_path(projects(:shop)), params: { message: { body: "Another change" } }
    end
  end
end
