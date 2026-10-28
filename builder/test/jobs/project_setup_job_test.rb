require "test_helper"

class ProjectSetupJobTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    @originals = Rails.configuration.x.projects_root, Rails.configuration.x.template_path
    Rails.configuration.x.projects_root = @root.join("projects")

    # A monorepo with the template in a folder, plus an edit not committed yet.
    monorepo = @root.join("monorepo")
    monorepo.join("storefront/config").mkpath
    monorepo.join("builder").mkpath
    monorepo.join("storefront/config/application.rb").write(%(config.x.app_name = "Starter"\n))
    monorepo.join("builder/app.rb").write("builder")
    monorepo.join("blocks/storefront_kit/lib").mkpath
    monorepo.join("blocks/storefront_kit/lib/storefront_kit.rb").write("module StorefrontKit; end")
    monorepo.join("storefront/vendor/blocks").mkpath
    File.symlink("../../../blocks/storefront_kit", monorepo.join("storefront/vendor/blocks/storefront_kit"))
    git = ProjectShell.new(monorepo)
    git.run("git", "init", "--quiet")
    git.run("git", "add", "--all")
    git.run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", "Monorepo")
    monorepo.join("storefront/README.md").write("not committed")
    Rails.configuration.x.template_path = monorepo.join("storefront")
  end

  teardown do
    Rails.configuration.x.projects_root, Rails.configuration.x.template_path = @originals
    FileUtils.rm_rf(@root)
  end

  test "starts the app from the template's last commit, in a repository of its own" do
    project = projects(:clinic)
    ProjectSetupJob.new.send(:copy_template, project)

    assert project.path.join("config/application.rb").exist?
    assert_not project.path.join("README.md").exist?
    assert_not project.path.join("builder").exist?
    assert_equal [ "Start from the template" ], project.shell.run("git", "log", "--format=%s").lines.map(&:chomp)
  end

  test "the app gets a copy of each block the template links to" do
    project = projects(:clinic)
    ProjectSetupJob.new.send(:copy_template, project)

    block = project.path.join("vendor/blocks/storefront_kit")
    assert block.directory?
    assert_not block.symlink?
    assert_equal "module StorefrontKit; end", block.join("lib/storefront_kit.rb").read
    assert_includes project.shell.run("git", "ls-files"), "vendor/blocks/storefront_kit/lib/storefront_kit.rb"
  end

  test "the app stays in English and gets the owner's time zone" do
    source = %(    # config.time_zone = "Central Time (US & Canada)"\n    config.i18n.default_locale = :en\n    config.time_zone = "UTC"\n)
    result = ProjectSetupJob.new.send(:localize, source, projects(:clinic))

    assert_match "config.i18n.default_locale = :en", result
    assert_match %(\n    config.time_zone = "#{projects(:clinic).time_zone}"), result
    assert_match %(# config.time_zone = "Central Time (US & Canada)"), result
  end

  test "a new app's Hallmark log remembers the owner's other shops, so its look isn't theirs" do
    Rails.configuration.x.projects_root.mkpath
    other, project = projects(:shop), projects(:clinic)
    other.path.join("app/assets/tailwind").mkpath
    other.path.join("app/assets/tailwind/theme.css").write(<<~CSS)
      /* Hallmark · shape: Split Studio · layout: soft · genre: playful · theme: Sticker (deal 1/3, seed x) · job: buy · draw: eabf0e
       * hero: Corridor · nav: banner over a retracting bar · footer: index columns · signature: the pet on the canvas
       * axes: light 95.7 82 / display-heavy Bowlby One SC / chromatic-magenta 2 · posture: full-palette · contrast: pass */
    CSS
    other.update_columns(owner_id: project.owner_id)

    ProjectSetupJob.new.send(:remember_other_looks, project)

    entry = JSON.parse(project.path.join(".hallmark/log.json").read).first
    assert_equal({ "theme" => "Sticker", "shape" => "Split Studio", "hero" => "Corridor", "nav" => "banner over a retracting bar", "footer" => "index columns" },
      entry.slice("theme", "shape", "hero", "nav", "footer"))
  end
end
