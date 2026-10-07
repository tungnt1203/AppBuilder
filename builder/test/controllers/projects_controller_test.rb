require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "lists apps" do
    get root_path

    assert_response :success
    assert_select "a", text: /Nha khoa/
  end

  test "a turn's summary offers to go back to the version it left, unless the app is on it" do
    project = projects(:clinic)
    project.messages.create!(role: :result, data: { "num_turns" => 3, "sha" => "aaa1111", "tree" => "tree-aaa1111" })
    project.messages.create!(role: :result, data: { "num_turns" => 4, "sha" => "bbb2222", "tree" => "tree-bbb2222" })
    project.messages.create!(role: :notice, body: "Restored “Version aaa1111”", data: { "sha" => "ccc3333", "tree" => "tree-aaa1111" })

    with_versions("ccc3333") do
      ProjectHistory.define_method(:current_tree) { "tree-aaa1111" }
      get project_path(project)
    end

    assert_select ".turn-done form[action='#{project_restorations_path(project)}'] input[name=sha][value=bbb2222]"
    assert_select "input[name=sha][value=aaa1111]", 0 # restored, so the app has these files now
    assert_select "input[name=sha][value=ccc3333]", 0
  end

  test "draws the studio in the theme the owner chose" do
    get root_path
    assert_select "html:not([data-theme])"
    assert_select "button[data-controller='theme'][data-theme-choice='system']"

    cookies[:theme] = "dark"
    get project_path(projects(:clinic))
    assert_select "html[data-theme='dark']"
    assert_select "header button[data-controller='theme'][data-theme-choice='dark']"
  end

  test "apps built by bin/eval stay off the home page" do
    projects(:clinic).update!(eval_run: "20261006-1000")

    get root_path
    assert_select "a[href='#{project_path(projects(:clinic))}']", 0
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

    project = Project.find_by!(name: "Phòng gym")
    assert_redirected_to project_path(project)
    assert_equal [ "user", "Quản lý hội viên" ], [ project.messages.first.role, project.messages.first.body ]
  end

  test "a new app is built straight away unless Plan first is on" do
    post projects_path, params: { project: { name: "Tiệm bánh", language: "vi", request: "Trang đặt bánh" } }
    assert_equal "build", enqueued_jobs.last["arguments"].last
  end

  test "a member over the monthly budget can't start a new app" do
    users(:member).usages.create!(cost_usd: 25)
    sign_in_as users(:member)

    assert_no_difference -> { Project.count } do
      post projects_path, params: { project: { name: "Tiệm bánh", language: "vi", request: "Trang đặt bánh" } }
    end
    assert_response :unprocessable_entity
    assert_match "budget for the agent is used up", response.body
  end

  test "an app needs a name or a description" do
    post projects_path, params: { project: { name: "", language: "vi", request: "" } }

    assert_response :unprocessable_entity
  end

  test "without a name, the app is called after its request until setup names it" do
    post projects_path, params: { project: { name: "", language: "vi", request: "Lễ tân quản lý bệnh nhân và đặt lịch hẹn" } }

    project = Project.last
    assert_equal "Lễ tân quản lý…", project.name
    assert project.name_pending?
    assert_redirected_to project_path(project)
  end


  test "shows the chat and the preview" do
    get project_path(projects(:clinic))

    assert_response :success
    assert_select "iframe[src='#{project_preview_path(projects(:clinic))}']"
    assert_select "#messages strong", "Lịch hẹn"
    assert_select "header .segmented button[data-preview-size-param]", 3
    assert_select "header [data-action='preview#toggleFullscreen']"
    assert_select "[data-preview-accepts-value='true']"
    assert_select ".stage .preview-error[hidden] form[action='#{project_messages_path(projects(:clinic))}'] input[data-preview-target='errorRequest']"
  end

  test "suggests what to ask for next until the owner sends something" do
    project = projects(:clinic)
    project.messages.create!(role: :assistant, body: "Xong.", data: { "next_steps" => [ "Thêm báo cáo doanh thu", "Nhắc lịch qua Zalo" ] })

    get project_path(project)
    assert_select ".next-steps button[data-action='next-step#use']", 2

    project.messages.create!(role: :user, body: "Thêm báo cáo doanh thu")
    get project_path(project)
    assert_select ".next-steps", 0
  end

  test "each card has a menu to rename, change the address, duplicate or delete, off while the app is busy" do
    get root_path

    assert_select "##{ActionView::RecordIdentifier.dom_id(projects(:clinic))} .menu-item:not([disabled])", 4
    assert_select "##{ActionView::RecordIdentifier.dom_id(projects(:shop))} .menu-item[disabled]", 4
    assert_select "dialog.modal input[name='project[name]'][value='Nha khoa']"
    assert_select "dialog.modal input[name='project[subdomain]'][value='nha-khoa']"
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

  test "changing the address shows what's wrong in the dialog" do
    project = projects(:clinic)

    patch project_address_path(project), params: { project: { subdomain: "www" } }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_match "is reserved", response.body
    assert_equal "nha-khoa", project.reload.subdomain
  end

  test "changing the address of an unpublished app saves it" do
    project = projects(:clinic)

    patch project_address_path(project), params: { project: { subdomain: "rang-dep" } }, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_equal "rang-dep", project.reload.subdomain
  end
end
