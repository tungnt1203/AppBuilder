require "test_helper"

class Projects::DesignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:owner)
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @project = projects(:clinic)
    storefront = Rails.root.join("../storefront")
    @project.path.join("app/assets/tailwind").mkpath
    FileUtils.cp(storefront.join("themes/clean/app/assets/tailwind/theme.css"), @project.path.join(ProjectDesign::FILE))
    FileUtils.cp(storefront.join("app/assets/tailwind/fonts.css"), @project.path.join(ProjectDesign::FONTS_FILE))
    @project.shell.run("git", "init", "--quiet")
    @project.shell.run("git", "add", "--all")
    @project.shell.run("git", "-c", "user.name=T", "-c", "user.email=t@example.com", "commit", "--quiet", "-m", "Set up")
    @sandbox_method = Project.instance_method(:sandbox)
    Project.define_method(:sandbox) { Struct.new(:commands) { def run(*) = "" }.new }
  end

  teardown do
    Project.define_method(:sandbox, @sandbox_method)
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "the Design tab shows the theme's colors, fonts and shape" do
    get project_design_path(@project)

    assert_response :success
    assert_select "turbo-frame#design form[data-controller=design]"
    assert_select "input[type=color][name='design[brand]'][value='#121212']"
    assert_select "select[name='design[heading_font]'] option[selected]", "Assistant"
    assert_select "input[type=radio][name='design[corners]'][value=square][checked]"
  end

  test "saving keeps the change as a version" do
    patch project_design_path(@project), params: { design: { brand: "#e8643c", background: "#fdfdfb", text: "#121212", accent: "#334fb4",
                                                             heading_font: "Fraunces", text_font: "Assistant", corners: "square", width: "standard" } }

    assert_response :success
    assert_match %(<turbo-stream action="update" target="design">), response.body
    assert_match "Saved as a version", response.body
    assert_match %(<turbo-stream action="update" target="versions">), response.body
    assert_match "Design: brand #e8643c and Fraunces", response.body
    assert_includes @project.path.join(ProjectDesign::FILE).read, "--color-brand-600: #e8643c;"
  end

  test "nothing is saved while the agent works" do
    @project.update!(status: :working)
    patch project_design_path(@project), params: { design: { brand: "#e8643c", background: "#fdfdfb", text: "#121212", accent: "#334fb4",
                                                             heading_font: "Assistant", text_font: "Assistant", corners: "square", width: "standard" } }

    assert_response :unprocessable_entity
    assert_select ".alert", /Wait until the current step finishes/
    assert_includes @project.path.join(ProjectDesign::FILE).read, "--color-brand-600: #121212;"
  end
end
