require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "lists apps" do
    get root_path

    assert_response :success
    assert_select "a", text: /Nha khoa/
  end

  test "home page offers ideas and shows each app as a card" do
    get root_path

    assert_select "h1", "What do you want to build?"
    assert_select ".idea", ProjectsHelper::SUGGESTIONS.size
    assert_select ".app-card", Project.count
    assert_select ".app-card .monogram", "N"
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
    assert_select "header .segmented button[data-preview-size-param]", 3
    assert_select "header [data-action='preview#toggleFullscreen']"
  end

  test "each card has a menu to rename, duplicate or delete, off while the app is busy" do
    get root_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(projects(:clinic))} .menu-item:not([disabled])", 3
    assert_select "##{ActionView::RecordIdentifier.dom_id(projects(:shop))} .menu-item[disabled]", 3
    assert_select "dialog.modal input[name='project[name]'][value='Nha khoa']"
  end

  test "renaming from the card" do
    patch project_path(projects(:clinic)), params: { project: { name: "Nha khoa Mai" } }

    assert_redirected_to root_path
    assert_equal "Nha khoa Mai", projects(:clinic).reload.name
  end

  test "a busy app isn't renamed, copied or deleted" do
    shop = projects(:shop)
    patch project_path(shop), params: { project: { name: "Other" } }
    post project_duplicate_path(shop)
    delete project_path(shop)

    assert_equal "Shop", shop.reload.name
    assert_equal 2, Project.count
  end
end
