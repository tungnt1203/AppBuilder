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
    assert_match "Now on the Bold layout", response.body
    assert_includes @commands, [ "bin/theme", "bold", "--force" ]
    assert_includes @commands, [ "bin/rails", "tailwindcss:build" ]
  end

  test "the Hallmark material shows as the look, and switching the layout keeps it" do
    use_themes
    require Rails.root.join("../storefront/lib/hallmark_material").to_s
    @project.path.join(".claude/skills").mkpath
    FileUtils.ln_s(Rails.root.join("../storefront/.claude/skills/hallmark"), @project.path.join(".claude/skills/hallmark"))
    HallmarkMaterial.new(@project.path, "sticker").apply!

    get project_design_path(@project)
    assert_select ".look-card[aria-current] p", /\ASticker/
    assert_select ".look-card[aria-current] img[src=?]", look_project_design_path(@project, "sticker")

    get look_project_design_path(@project, "sticker")
    assert_equal "image/jpeg", response.media_type
    get look_project_design_path(@project, "nope")
    assert_response :not_found

    post theme_project_design_path(@project), params: { theme: "bold", force: "1" }
    assert_includes @commands, [ "bin/theme", "bold", "--force" ]
    css = @project.path.join(ProjectDesign::FILE).read
    assert_includes css, "bin/theme material sticker"
    assert_includes css, "layout: bold"
    assert_includes @project.path.join("app/views/layouts/_fonts.html.erb").read, "Bowlby One SC"
  end

  test "a look is tried on in seconds without the agent, then kept as a version or taken back" do
    use_themes
    require Rails.root.join("../storefront/lib/hallmark_material").to_s
    @project.path.join(".claude/skills").mkpath
    FileUtils.ln_s(Rails.root.join("../storefront/.claude/skills/hallmark"), @project.path.join(".claude/skills/hallmark"))
    HallmarkMaterial.new(@project.path, "sticker").apply!
    before = @project.path.join(ProjectDesign::FILE).read

    post try_look_project_design_path(@project, "piste")
    assert_response :success
    assert_includes @commands, [ "bin/theme", "material", "piste" ]
    assert_includes @commands, [ "bin/rails", "tailwindcss:build" ]
    @project.path.join(ProjectDesign::FILE).write("/* piste */") # what bin/theme would have written
    get project_design_path(@project)
    assert_select ".look-trying form[action=?]", keep_look_project_design_path(@project)

    post revert_look_project_design_path(@project)
    assert_equal before, @project.path.join(ProjectDesign::FILE).read
    assert_not ProjectTheme.new(@project).trying?

    post try_look_project_design_path(@project, "piste")
    versions = @project.history.versions.size
    post keep_look_project_design_path(@project)
    assert_not ProjectTheme.new(@project).trying?
    assert_equal versions + 1, @project.history.versions.size

    post try_look_project_design_path(@project, "nope")
    assert_response :not_found
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

  test "a choice shows with its options in plain words, and the owner's pick becomes the shop's value" do
    @project.update!(shop: shops(:cats))
    @project.path.join("config").mkpath
    @project.path.join("config/theme_settings.yml").write(<<~YAML)
      - key: product_layout
        type: select
        label: Product page layout
        options: [ split, flip ]
        option_labels: { split: "Photos on the left" }
        default: split
    YAML

    get project_design_path(@project)
    assert_select "select[name='content[texts][product_layout]']" do
      assert_select "option[value=split][selected]", "Photos on the left"
      assert_select "option[value=flip]", "Flip"
    end

    patch content_project_design_path(@project), params: { content: { texts: { product_layout: "flip" } } }
    assert_equal({ "product_layout" => "flip" }, ActsAsTenant.with_tenant(shops(:cats)) { ThemeSetting.current.values })
    patch content_project_design_path(@project), params: { content: { texts: { product_layout: "sideways" } } }
    assert_select "p.alert", /pick one of the choices/
  end

  test "finding a stock photo and using it: the theme's default, a credit and a version" do
    @project.update!(shop: shops(:cats))
    @project.path.join("config").mkpath
    @project.path.join("config/theme_settings.yml").write(<<~YAML)
      # The theme's settings.
      - key: hero_image
        type: image
        label: Home page photo (wide)
      - { key: story_image, type: image, label: Story photo, default: "https://images.unsplash.com/photo-1?w=1600" }
    YAML
    @project.shell.run("git", "add", "--all")
    @project.shell.run("git", "-c", "user.name=T", "-c", "user.email=t@example.com", "commit", "--quiet", "-m", "Settings")
    found = [ StockPhotos::Photo.new(url: "https://images.unsplash.com/photo-2?w=1600", thumb: "https://images.unsplash.com/photo-2?w=400",
                                     credit: "Photo by Ana on Unsplash", page: "https://unsplash.com/photos/2", download: nil) ]
    search = StockPhotos.method(:search)
    StockPhotos.define_singleton_method(:search) { |query, **| query == "runners" ? found : [] }

    get photos_project_design_path(@project, key: "hero_image", q: "runners")
    assert_select "turbo-frame#photos_hero_image button[form=photo_use] img[alt='Photo by Ana on Unsplash']"
    assert_select "a", text: "More photos", count: 0 # fewer than a page

    StockPhotos.define_singleton_method(:search) { |query, page: 1, **| page == 1 ? found * 9 : found }
    get photos_project_design_path(@project, key: "hero_image", q: "runners")
    assert_select "turbo-frame#photos_hero_image_page_2 a[href*='page=2']", "More photos"
    get photos_project_design_path(@project, key: "hero_image", q: "runners", page: 2)
    assert_select "turbo-frame#photos_hero_image_page_2 li button[form=photo_use]", 1

    choice = { key: "hero_image", url: found.first.url, credit: found.first.credit, page: found.first.page }.to_json
    post photo_project_design_path(@project), params: { choice: }
    assert_response :success
    settings = YAML.safe_load_file(@project.path.join("config/theme_settings.yml"))
    assert_equal "https://images.unsplash.com/photo-2?w=1600", settings.first["default"]
    assert_includes @project.path.join("config/theme_settings.yml").read, "# The theme's settings."
    assert_includes @project.path.join("app/assets/images/stock/CREDITS.md").read, "Photo by Ana on Unsplash"
    assert_equal "Photo: Home page photo", @project.shell.run("git", "log", "-1", "--format=%s").strip

    post photo_project_design_path(@project), params: { choice: choice.sub("hero_image", "story_image") }
    assert_equal "https://images.unsplash.com/photo-2?w=1600", YAML.safe_load_file(@project.path.join("config/theme_settings.yml")).last["default"]
  ensure
    StockPhotos.define_singleton_method(:search, search) if search
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
