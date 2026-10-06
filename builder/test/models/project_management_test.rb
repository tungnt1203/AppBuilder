require "test_helper"

class ProjectManagementTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @project = projects(:clinic)

    @project.path.join("config").mkpath
    @project.path.join("config/application.rb").write(%(module App\n  config.x.app_name = "Nha khoa"\nend\n))
    @project.path.join("storage").mkpath
    @project.path.join("storage/development.sqlite3").write("data")
    @project.path.join("tmp/pids").mkpath
    @project.path.join("tmp/pids/server.pid").write("123")
    git "init", "--quiet", "--initial-branch=main"
    git "add", "--all"
    git "commit", "--quiet", "-m", "Set up Nha khoa"
  end

  teardown do
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "renaming changes the record now and the app's code in a job" do
    assert_enqueued_with(job: RenameJob, args: [ @project ]) { assert @project.rename("  Nha khoa  Mai ") }
    assert_equal "Nha khoa Mai", @project.reload.name
    assert_equal "nha-khoa", @project.slug
    assert @project.working?

    stub_preview(@project) { RenameJob.perform_now(@project) }

    assert_match 'config.x.app_name = "Nha khoa Mai"', @project.path.join("config/application.rb").read
    assert_equal "Rename the app to Nha khoa Mai", @project.history.versions.first.subject
    assert @project.reload.ready?
    assert_match "renamed the app", @project.agent_note
  end

  test "renaming to the same name does nothing" do
    assert_no_enqueued_jobs { assert @project.rename("Nha khoa") }
    assert @project.reload.ready?
  end

  test "an app can't be renamed to nothing" do
    assert_not @project.rename(" ")
    assert_equal "Nha khoa", @project.reload.name
  end

  test "duplicating copies code, history and data but not the running server" do
    copy = nil
    assert_enqueued_with(job: DuplicateJob) { copy = @project.duplicate }
    assert_equal [ "Nha khoa (bản sao)", "nha-khoa-ban-sao", "vi" ], [ copy.name, copy.slug, copy.language ]
    assert copy.setting_up?
    assert_not_equal @project.port, copy.port

    stub_preview(copy) { DuplicateJob.perform_now(copy, @project) }

    assert_equal "data", copy.path.join("storage/development.sqlite3").read
    assert_not copy.path.join("tmp/pids/server.pid").exist?
    assert_match 'config.x.app_name = "Nha khoa (bản sao)"', copy.path.join("config/application.rb").read
    assert_equal [ "Copy “Nha khoa” as Nha khoa (bản sao)", "Set up Nha khoa" ], copy.history.versions.map(&:subject).first(2)
    assert copy.reload.ready?
    assert_equal "Copied from “Nha khoa”: its code, versions and preview data.", copy.messages.last.body
    assert_match 'app_name = "Nha khoa"', @project.path.join("config/application.rb").read
  end

  test "deleting stops the preview and removes the folder" do
    preview = Object.new
    def preview.stop = @stopped = true
    def preview.stopped? = @stopped
    @project.define_singleton_method(:preview) { preview }

    @project.remove

    assert preview.stopped?
    assert_not Project.exists?(@project.id)
    assert_not @project.path.exist?
  end

  private
    def git(*args)
      ProjectShell.new(@project.path).run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", *args)
    end

    def stub_preview(project)
      Project.class_eval { alias_method :original_restart_preview, :restart_preview; define_method(:restart_preview) { |**| update!(preview_status: :running) } }
      yield
    ensure
      Project.class_eval { alias_method :restart_preview, :original_restart_preview; remove_method :original_restart_preview }
    end
end
