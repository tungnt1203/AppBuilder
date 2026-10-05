require "test_helper"

class ProjectHistoryTest < ActiveSupport::TestCase
  setup do
    @root = Pathname(Dir.mktmpdir)
    @project = projects(:clinic)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root

    git "init", "--quiet", "--initial-branch=main"
    commit "Template", "README.md" => "template"
    @project.update!(base_sha: commit("Set up Nha khoa", "app.rb" => "v1"))
    commit "Add patients", "patients.rb" => "patients"
  end

  teardown do
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "lists versions since setup, newest first" do
    assert_equal [ "Add patients", "Set up Nha khoa" ], @project.history.versions.map(&:subject)
  end

  test "restoring brings back the old files as a new version" do
    setup_version = @project.history.versions.last

    @project.history.restore(setup_version)

    assert_not @project.path.join("patients.rb").exist?
    assert_equal "v1", @project.path.join("app.rb").read
    assert_equal [ "Restore “Set up Nha khoa”", "Add patients", "Set up Nha khoa" ], @project.history.versions.map(&:subject)
  end

  test "a restore can itself be undone" do
    @project.history.restore(@project.history.versions.last)
    @project.history.restore(@project.history.find(@project.history.versions.second.sha))

    assert_equal "patients", @project.path.join("patients.rb").read
  end

  test "a repository still being copied has no versions" do
    FileUtils.rm_rf(@project.path.join(".git"))
    git "init", "--quiet"

    assert_empty @project.history.versions
  end

  test "projects without a repository yet have no versions" do
    FileUtils.rm_rf(@project.path.join(".git"))
    assert_empty @project.history.versions
  end

  test "takes the agent's commit message once" do
    @project.path.join("tmp").mkpath
    @project.path.join("tmp/commit_message.txt").write("Thêm danh sách bệnh nhân\n")

    assert_equal "Thêm danh sách bệnh nhân", @project.take_commit_message
    assert_nil @project.take_commit_message
  end

  private
    def git(*args)
      @project.path.mkpath
      @project.shell.run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", *args)
    end

    def commit(message, files)
      files.each { |name, content| @project.path.join(name).write(content) }
      git "add", "--all"
      git "commit", "--quiet", "-m", message
      git("rev-parse", "--short", "HEAD").strip
    end
end
