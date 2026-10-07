require "test_helper"

class ProjectSetupJobTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    @originals = Rails.configuration.x.projects_root, Rails.configuration.x.template_path
    Rails.configuration.x.projects_root = @root.join("projects")

    # A monorepo with the template in a folder, plus an edit not committed yet.
    monorepo = @root.join("monorepo")
    monorepo.join("template/config").mkpath
    monorepo.join("builder").mkpath
    monorepo.join("template/config/application.rb").write(%(config.x.app_name = "Starter"\n))
    monorepo.join("builder/app.rb").write("builder")
    git = ProjectShell.new(monorepo)
    git.run("git", "init", "--quiet")
    git.run("git", "add", "--all")
    git.run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", "Monorepo")
    monorepo.join("template/README.md").write("not committed")
    Rails.configuration.x.template_path = monorepo.join("template")
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

  test "the app stays in English and gets the owner's time zone" do
    source = %(    # config.time_zone = "Central Time (US & Canada)"\n    config.i18n.default_locale = :en\n    config.time_zone = "UTC"\n)
    result = ProjectSetupJob.new.send(:localize, source, projects(:clinic))

    assert_match "config.i18n.default_locale = :en", result
    assert_match %(\n    config.time_zone = "#{projects(:clinic).time_zone}"), result
    assert_match %(# config.time_zone = "Central Time (US & Canada)"), result
  end
end
