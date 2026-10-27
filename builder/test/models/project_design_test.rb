require "test_helper"

class ProjectDesignTest < ActiveSupport::TestCase
  # Answers every command, recording them.
  class FakeSandbox
    attr_reader :commands

    def initialize = @commands = []
    def run(*command, **) = (@commands << command; "")
  end

  setup do
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
    @sandbox = FakeSandbox.new
    @sandbox_method = Project.instance_method(:sandbox)
    sandbox = @sandbox
    Project.define_method(:sandbox) { sandbox }
  end

  teardown do
    Project.define_method(:sandbox, @sandbox_method)
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "reads the theme's colors, fonts, corners and width" do
    design = ProjectDesign.for(@project)

    assert design.available?
    assert_equal "#121212", design.brand
    assert_equal "#fdfdfb", design.background
    assert_equal "Assistant", design.heading_font
    assert_equal "square", design.corners
    assert_equal "standard", design.width
    assert_includes design.fonts, "Fraunces"
    assert_not_includes design.fonts, "JetBrains Mono"
  end

  test "saving writes the theme, rebuilds the styles and keeps a version" do
    design = ProjectDesign.for(@project)
    design.assign_attributes(brand: "#e8643c", heading_font: "Fraunces", corners: "soft")

    assert design.save
    css = @project.path.join(ProjectDesign::FILE).read
    assert_includes css, "--color-brand-600: #e8643c;"
    assert_includes css, "--color-brand-50: color-mix(in oklch, #e8643c 8%, white);"
    assert_includes css, "--color-brand-900: color-mix(in oklch, #e8643c 55%, black);"
    assert_includes css, "--color-on-brand: #1a1a1a;" # dark words read better on this orange than white
    assert_includes css, %(--font-display: "Fraunces", ui-sans-serif)
    assert_includes css, %(--font-sans: "Assistant", ui-sans-serif)
    assert_includes css, "--radius-lg: 10px;"
    assert_equal [ [ "bin/rails", "tailwindcss:build" ] ], @sandbox.commands
    assert_equal "Design: brand #e8643c, Fraunces, and soft corners", @project.shell.run("git", "log", "-1", "--format=%s").strip
    assert_equal "#e8643c", ProjectDesign.for(@project).brand
  end

  test "on a dark theme the brand scale turns around, and a surface of its own is kept" do
    FileUtils.cp(Rails.root.join("../storefront/themes/bold/app/assets/tailwind/theme.css"), @project.path.join(ProjectDesign::FILE))
    design = ProjectDesign.for(@project)
    design.heading_font = "Fraunces"

    assert design.save
    css = @project.path.join(ProjectDesign::FILE).read
    assert_includes css, "--color-surface: #28282b;"
    assert_includes css, "--color-brand-50: color-mix(in oklch, #e3fc02 8%, black);"
    assert_includes css, "--color-brand-900: color-mix(in oklch, #e3fc02 55%, white);"
  end

  test "a dark brand color gets white words on it; nothing changed or a bad color saves nothing" do
    design = ProjectDesign.for(@project)
    assert_not design.save

    design.brand = "lime"
    assert_not design.save
    assert design.errors.of_kind?(:brand, :invalid)

    design.brand = "#1d4ed8"
    assert design.save
    assert_includes @project.path.join(ProjectDesign::FILE).read, "--color-on-brand: #ffffff;"
  end
end
