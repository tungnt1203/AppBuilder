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
    @commands = commands = []
    @sandbox_method = Project.instance_method(:sandbox)
    Project.define_method(:sandbox) { Struct.new(:commands) { def run(*command) = (commands << command; "") }.new(commands) }
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

  test "switching the theme runs the template's bin/theme and keeps it as a version" do
    use_themes
    get project_design_path(@project)
    assert_select ".design-theme[aria-current] p", "Clean"

    post theme_project_design_path(@project), params: { theme: "bold" }

    assert_response :success
    assert_match "Now on Bold", response.body
    assert_includes @commands, [ "bin/theme", "bold", "--force" ]
    assert_includes @commands, [ "bin/rails", "tailwindcss:build" ]
  end

  test "a file changed for this shop is listed before a switch replaces it" do
    use_themes
    @project.path.join("app/views/home/show.html.erb").write("<h1>Our own home page</h1>\n")

    post theme_project_design_path(@project), params: { theme: "bold" }

    assert_response :unprocessable_entity
    assert_select ".design-conflict li", "app/views/home/show.html.erb"
    assert_select ".design-conflict form input[name=force][value='1']"
    assert_empty @commands

    post theme_project_design_path(@project), params: { theme: "bold", force: "1" }
    assert_includes @commands, [ "bin/theme", "bold", "--force" ]
  end

  test "words and photos become the shop's values; one put back to the default stops overriding it" do
    @project.update!(shop: shops(:cats))
    @project.path.join("config").mkpath
    @project.path.join("config/theme_settings.yml").write(<<~YAML)
      - { key: hero_title, type: text, label: Home page headline, default: "Tees for cat people" }
      - { key: hero_text, type: text, label: Home page text, default: "Printed to order." }
      - { key: hero_image, type: image, label: Home page photo }
      - { key: show_benefits, type: boolean, label: Benefits, default: true }
    YAML

    get project_design_path(@project)
    assert_select "input[name='content[texts][hero_title]'][value='Tees for cat people']"
    assert_select "input[type=file][name='content[photos][hero_image]']"
    assert_select "input[name='content[texts][show_benefits]']", 0

    patch content_project_design_path(@project), params: { content: { texts: { hero_title: "Chubby cats only", hero_text: "Printed to order." },
                                                                     photos: { hero_image: fixture_file_upload("product.png", "image/png") } } }
    assert_response :success
    setting = ActsAsTenant.with_tenant(shops(:cats)) { ThemeSetting.current }
    assert_equal({ "hero_title" => "Chubby cats only" }, setting.values)
    assert setting.image_attachment("hero_image")

    patch content_project_design_path(@project), params: { content: { texts: { hero_title: "Tees for cat people" } } }
    assert_empty setting.reload.values
  end

  private
    def use_themes
      themes = Rails.root.join("../storefront/themes")
      FileUtils.cp_r(themes, @project.path.join("themes"))
      clean = @project.path.join("themes/clean")
      clean.glob("**/*").select(&:file?).reject { |file| file.basename.to_s == "README.md" }.each do |file|
        target = @project.path.join(file.relative_path_from(clean))
        target.dirname.mkpath
        FileUtils.cp(file, target)
      end
    end
end
