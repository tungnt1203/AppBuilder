require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "lists apps" do
    get root_path

    assert_response :success
    assert_select "a", text: /Nha khoa/
  end

  test "creating an app puts the request in the chat and starts setup" do
    assert_enqueued_with(job: ProjectSetupJob) do
      post projects_path, params: { project: { name: "Phòng gym", language: "vi", request: "Quản lý hội viên", plan: "1" } }
    end
    assert_equal "plan", enqueued_jobs.last["arguments"].last

    project = Project.find_by!(slug: "phong-gym")
    assert_redirected_to project_path(project)
    assert_equal [ "user", "Quản lý hội viên" ], [ project.messages.first.role, project.messages.first.body ]
  end

  test "an app needs a name" do
    post projects_path, params: { project: { name: "", language: "vi" } }

    assert_response :unprocessable_entity
  end

  test "shows the chat and the preview" do
    get project_path(projects(:clinic))

    assert_response :success
    assert_select "iframe[src='http://localhost:4001']"
    assert_select "#messages strong", "Lịch hẹn"
  end
end
