require "test_helper"

class ProjectBlocksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # A sandbox that answers every command, recording them; the app's tests pass unless told.
  class FakeSandbox
    attr_reader :commands
    attr_accessor :tests_pass

    def initialize = (@commands, @tests_pass = [], true)
    def run(*command, **) = (@commands << command; "")

    def capture(*command, **)
      @commands << command
      command.last == "test" ? [ (tests_pass ? "0 failures" : "1 failure: OrdersTest"), tests_pass ] : [ "", true ]
    end
  end

  setup do
    @root = Pathname(Dir.mktmpdir)
    @originals = Rails.configuration.x.projects_root, Rails.configuration.x.template_path
    Rails.configuration.x.projects_root = @root.join("projects")

    @monorepo = @root.join("monorepo")
    @monorepo.join("template/config").mkpath
    @monorepo.join("template/config/application.rb").write(%(config.x.app_name = "Starter"\n))
    @monorepo.join("blocks/shop/lib").mkpath
    @monorepo.join("blocks/shop/lib/shop.rb").write("module Shop; end")
    @monorepo.join("template/vendor/blocks").mkpath
    File.symlink("../../../blocks/shop", @monorepo.join("template/vendor/blocks/shop"))
    commit_monorepo "Add the shop core"
    Rails.configuration.x.template_path = @monorepo.join("template")

    @project = projects(:clinic)
    ProjectSetupJob.new.send(:copy_template, @project)
  end

  teardown do
    Rails.configuration.x.projects_root, Rails.configuration.x.template_path = @originals
    FileUtils.rm_rf(@root)
  end

  test "an app made from the latest blocks is up to date" do
    assert_not @project.blocks.outdated?
  end

  test "a newer block shows what changed since the app's copy, and updating brings it" do
    @monorepo.join("blocks/shop/lib/shop.rb").write("module Shop; VERSION = 2; end")
    commit_monorepo "Fix checkout"
    @monorepo.join("blocks/shop/lib/order.rb").write("class Order; end")
    commit_monorepo "Let buyers review"
    @monorepo.join("template/README.md").write("not about the block")
    commit_monorepo "Change the template only"

    assert_equal({ "shop" => [ "Let buyers review", "Fix checkout" ] }, @project.blocks.updates)
    assert_equal "shop core", @project.blocks.titles

    assert_equal [ "shop" ], @project.blocks.update!
    assert_equal "module Shop; VERSION = 2; end", @project.path.join("vendor/blocks/shop/lib/shop.rb").read
    @project.history.commit("Update the shop core")
    assert_not @project.blocks.outdated?
  end

  test "a copy changed by hand is outdated, with no list of changes" do
    @project.path.join("vendor/blocks/shop/lib/shop.rb").write("module Shop; HACK = 1; end")
    @project.history.commit("Edit the core")

    assert_equal({ "shop" => [] }, @project.blocks.updates)
  end

  test "updating is a version of its own, with migrations, the tests and a note for the agent" do
    @monorepo.join("blocks/shop/lib/shop.rb").write("module Shop; VERSION = 2; end")
    commit_monorepo "Fix checkout"
    sandbox = FakeSandbox.new

    assert @project.update_blocks
    assert @project.reload.working?
    with_fakes(sandbox) { perform_enqueued_jobs(only: BlockUpdateJob) }

    @project.reload
    assert @project.ready?
    assert_equal "Update the shop core", @project.shell.run("git", "log", "-1", "--format=%s").strip
    assert_includes sandbox.commands, [ "bin/rails", "db:migrate" ]
    assert_equal "Updated the shop core", @project.messages.last.body
    assert_match "vendor/blocks/shop", @project.agent_note
    assert_match "- Fix checkout", @project.agent_note
    assert_no_enqueued_jobs(only: AgentTurnJob)
  end

  test "when the app's tests fail with the new core, the agent fixes the app" do
    @monorepo.join("blocks/shop/lib/shop.rb").write("module Shop; VERSION = 2; end")
    commit_monorepo "Fix checkout"
    sandbox = FakeSandbox.new
    sandbox.tests_pass = false

    @project.update_blocks
    with_fakes(sandbox) { perform_enqueued_jobs(only: BlockUpdateJob) }

    job = enqueued_jobs.find { |enqueued| enqueued["job_class"] == "AgentTurnJob" }
    assert job
    request = ActiveJob::Arguments.deserialize(job["arguments"])[1]
    assert_match "never change vendor/blocks", request
    assert_match "OrdersTest", request
  end

  test "an app that's busy isn't updated" do
    @project.update!(status: :working)
    assert_not @project.update_blocks
    assert_no_enqueued_jobs(only: BlockUpdateJob)
  end

  private
    def commit_monorepo(message)
      git = ProjectShell.new(@monorepo)
      git.run("git", "init", "--quiet") unless @monorepo.join(".git").exist?
      git.run("git", "add", "--all")
      git.run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", message)
    end

    def with_fakes(sandbox)
      sandbox_method, restart = Project.instance_method(:sandbox), Project.instance_method(:restart_preview)
      Project.define_method(:sandbox) { sandbox }
      Project.define_method(:restart_preview) { |restart: true| nil }
      yield
    ensure
      Project.define_method(:sandbox, sandbox_method)
      Project.define_method(:restart_preview, restart)
    end
end
