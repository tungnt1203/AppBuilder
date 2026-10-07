require "test_helper"

class Projects::CodesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  setup do
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @project = projects(:clinic)
    @project.path.join("config").mkpath
    @project.path.join("config/routes.rb").write("Rails.application.routes.draw do\nend\n")
    shell = ProjectShell.new(@project.path)
    shell.run("git", "init", "--quiet")
    shell.run("git", "add", "--all")
    shell.run("git", "-c", "user.name=T", "-c", "user.email=t@example.com", "commit", "--quiet", "-m", "Set up")
  end

  teardown do
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "shows the files and opens one, highlighted" do
    get project_code_path(@project)

    assert_response :success
    assert_select "turbo-frame#code .code-tree a[title='config/routes.rb']"
    assert_select ".code-head .url", "config/routes.rb"
    assert_select ".code-lines li", 2
    assert_select ".code-lines .k", "end"
  end

  test "a file outside the project is not found" do
    get project_code_path(@project, path: "../../config/master.key")

    assert_response :not_found
  end
end
