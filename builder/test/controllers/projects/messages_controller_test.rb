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

  test "with the plain cli agent, waits while it's working" do
    with_agent_backend("cli") do
      assert_no_enqueued_jobs do
        post project_messages_path(projects(:shop)), params: { message: { body: "Another change" } }
      end
    end
    assert_empty projects(:shop).agent_commands
  end

  test "with the interactive agent, a message joins the running turn" do
    with_agent_backend("sdk") do
      assert_no_enqueued_jobs(only: AgentTurnJob) do
        post project_messages_path(projects(:shop)), params: { message: { body: "Thêm cả số Zalo" } }
      end
    end

    assert_equal({ "text" => "Thêm cả số Zalo" }, projects(:shop).agent_commands.message.sole.payload)
    assert_equal "Thêm cả số Zalo", projects(:shop).messages.last.body
  end

  test "answers go to the waiting agent" do
    post project_messages_path(projects(:shop)), params: { message: {
      ask_id: "toolu_1", body: "ignored", answers: { "Khách có cần tài khoản không?" => "Không" }.to_json } }

    command = projects(:shop).agent_commands.answer.sole
    assert_equal({ "id" => "toolu_1", "answers" => { "Khách có cần tài khoản không?" => "Không" } }, command.payload)
    assert_equal({ "type" => "answer", "id" => "toolu_1", "answers" => { "Khách có cần tài khoản không?" => "Không" } }, JSON.parse(command.to_line))
  end
end
