require "test_helper"

class Projects::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

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

  test "answers to the agent's questions start the next turn" do
    assert_enqueued_with(job: AgentTurnJob, args: [ projects(:clinic), "Khách có cần tài khoản không? Không", "plan" ]) do
      post project_messages_path(projects(:clinic)), params: { message: { body: "Khách có cần tài khoản không? Không", plan: "1" } }
    end
  end

  test "attached files go to the agent and show in the chat" do
    project = projects(:clinic)
    with_projects_root do
      assert_enqueued_jobs 1, only: AgentTurnJob do
        post project_messages_path(project), params: { message: { body: "Dùng logo này", plan: "0",
          files: [ fixture_file_upload("logo.png", "image/png"), fixture_file_upload("menu.txt", "text/plain"), fixture_file_upload("run.sh", "application/x-sh") ] } }
      end

      message = project.messages.user.last
      assert_equal [ "logo.png", "menu.txt" ], message.data["attachments"].map { |attachment| attachment["name"] }
      assert project.path.join("tmp/attachments/#{message.id}/logo.png").exist?

      request = enqueued_jobs.last["arguments"][1]
      assert request.start_with?("Dùng logo này")
      assert_includes request, "- tmp/attachments/#{message.id}/logo.png (image/png)"

      get project_path(project)
      assert_select ".sent-attachments img[src='#{project_attachment_path(project, message_id: message.id, name: "logo.png")}']"

      get project_attachment_path(project, message_id: message.id, name: "logo.png")
      assert_response :success
      assert_equal "image/png", response.media_type
      assert_equal "sandbox", response.headers["Content-Security-Policy"]
    end
  end

  test "the part of the preview the owner pointed at goes with the message" do
    project = projects(:clinic)
    pointed = { page: "/", selector: "header > a.logo", tag: "a", text: "Nha khoa", html: "<a class=\"logo\">Nha khoa</a>" }.to_json

    post project_messages_path(project), params: { message: { body: "Làm logo này to hơn", plan: "0", pointed: } }

    request = enqueued_jobs.last["arguments"][1]
    assert request.start_with?("Làm logo này to hơn\n\nThe owner pointed at this part of the page / in the preview")
    assert_equal "header > a.logo", project.messages.user.last.data.dig("pointed", "selector")

    get project_path(project)
    assert_select ".pointed-note", text: /Nha khoa/
  end

  test "files alone are a message" do
    with_projects_root do
      post project_messages_path(projects(:clinic)), params: { message: { body: "", files: [ fixture_file_upload("logo.png", "image/png") ] } }
    end

    assert_equal "", projects(:clinic).messages.user.last.body
    assert projects(:clinic).reload.working?
  end

  test "only attached files can be opened" do
    with_projects_root do
      message = projects(:clinic).messages.create!(role: :user, body: "Hi")
      get project_attachment_path(projects(:clinic), message_id: message.id, name: "..%2F..%2Fconfig%2Fmaster.key")
      assert_response :not_found
    end
  end

  private
    def with_projects_root
      root = Pathname(Dir.mktmpdir)
      original, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, root
      yield
    ensure
      Rails.configuration.x.projects_root = original
      FileUtils.rm_rf(root)
    end
end
