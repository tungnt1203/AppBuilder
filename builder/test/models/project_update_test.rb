require "test_helper"

class ProjectUpdateTest < ActiveSupport::TestCase
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
    @monorepo.join("storefront/config").mkpath
    @monorepo.join("storefront/config/application.rb").write(%(config.x.app_name = "Starter"\n))
    @monorepo.join("storefront/app/views/products").mkpath
    @monorepo.join("storefront/app/views/products/show.html.erb").write("<h1>Product</h1>\n")
    @monorepo.join("storefront/app/views/orders").mkpath
    @monorepo.join("storefront/app/views/orders/show.html.erb").write("<h1>Order</h1>\n")
    @monorepo.join("storefront/CLAUDE.md").write("Rules\n")
    @monorepo.join("storefront/bin").mkpath
    @monorepo.join("blocks/storefront_kit/lib").mkpath
    @monorepo.join("blocks/storefront_kit/lib/storefront_kit.rb").write("module StorefrontKit; end")
    @monorepo.join("storefront/vendor/blocks").mkpath
    File.symlink("../../../blocks/storefront_kit", @monorepo.join("storefront/vendor/blocks/storefront_kit"))
    commit_monorepo "Add the storefront kit"
    Rails.configuration.x.template_path = @monorepo.join("storefront")

    @project = projects(:clinic)
    ProjectSetupJob.new.send(:copy_template, @project)
    @project.reload
  end

  teardown do
    Rails.configuration.x.projects_root, Rails.configuration.x.template_path = @originals
    FileUtils.rm_rf(@root)
  end

  test "an app made from the latest blocks is up to date" do
    assert_not @project.blocks.outdated?
    assert_not @project.template.outdated?
    assert_equal ProjectShell.new(@monorepo).run("git", "rev-parse", "HEAD").strip, @project.template_sha
  end

  test "template changes go in as they are where the app didn't change the file, and are left for the agent where it did" do
    @project.path.join("app/views/products/show.html.erb").write("<h1 class=peach>Product</h1>\n") # the app's own design
    @project.history.commit("Restyle")

    @monorepo.join("storefront/app/views/products/show.html.erb").write("<h1>Product</h1>\n<%= render 'reviews' %>\n")
    @monorepo.join("storefront/app/views/orders/show.html.erb").write("<h1>Order</h1>\n<a>Write a review</a>\n")
    @monorepo.join("storefront/app/views/orders/reviews.html.erb").write("Reviews\n")
    @monorepo.join("storefront/bin/look").write("#!/bin/sh\n")
    @monorepo.join("storefront/bin/look").chmod(0o755)
    @monorepo.join("storefront/CLAUDE.md").write("Rules\nReviews are built in\n")
    @monorepo.join("storefront/storage").mkpath
    @monorepo.join("storefront/storage/dev.sqlite3").write("data")
    commit_monorepo "Let buyers review what they bought"

    template = @project.template
    assert template.outdated?
    assert_equal [ "Let buyers review what they bought" ], template.changes
    assert_not_includes template.files.map(&:last), "storage/dev.sqlite3"

    result = template.apply!
    assert_equal %w[ CLAUDE.md app/views/orders/reviews.html.erb app/views/orders/show.html.erb bin/look ], result.updated.sort
    assert_equal [ "app/views/products/show.html.erb" ], result.left
    assert_match "Write a review", @project.path.join("app/views/orders/show.html.erb").read
    assert @project.path.join("bin/look").executable?
    assert_equal "<h1 class=peach>Product</h1>\n", @project.path.join("app/views/products/show.html.erb").read
    assert_match "render 'reviews'", @project.path.join("tmp/template_update/app/views/products/show.html.erb.diff").read
    assert_not @project.path.join("storage/dev.sqlite3").exist?
    assert_not @project.reload.template.outdated?
  end

  test "an app made before the builder kept its template commit starts from the one before its setup" do
    first = ProjectShell.new(@monorepo).run("git", "rev-parse", "HEAD").strip
    @project.update!(template_sha: nil)
    @monorepo.join("storefront/CLAUDE.md").write("Rules\nNew\n")
    commit_monorepo "Explain more", at: 1.hour.from_now
    assert_equal first, ProjectTemplate.new(@project).base
  end

  test "a newer block shows what changed since the app's copy, and updating brings it" do
    @monorepo.join("blocks/storefront_kit/lib/storefront_kit.rb").write("module StorefrontKit; VERSION = 2; end")
    commit_monorepo "Fix checkout"
    @monorepo.join("blocks/storefront_kit/lib/order.rb").write("class Order; end")
    commit_monorepo "Let buyers review"
    @monorepo.join("storefront/README.md").write("not about the block")
    commit_monorepo "Change the template only"

    assert_equal({ "storefront_kit" => [ "Let buyers review", "Fix checkout" ] }, @project.blocks.updates)
    assert_equal "storefront kit", @project.blocks.titles

    assert_equal [ "storefront_kit" ], @project.blocks.update!
    assert_equal "module StorefrontKit; VERSION = 2; end", @project.path.join("vendor/blocks/storefront_kit/lib/storefront_kit.rb").read
    @project.history.commit("Update the shop core")
    assert_not @project.blocks.outdated?
  end

  test "a copy changed by hand is outdated, with no list of changes" do
    @project.path.join("vendor/blocks/storefront_kit/lib/storefront_kit.rb").write("module StorefrontKit; HACK = 1; end")
    @project.history.commit("Edit the core")

    assert_equal({ "storefront_kit" => [] }, @project.blocks.updates)
  end

  test "updating is a version of its own, with the tests and a note for the agent" do
    @monorepo.join("blocks/storefront_kit/lib/storefront_kit.rb").write("module StorefrontKit; VERSION = 2; end")
    commit_monorepo "Fix checkout"
    sandbox = FakeSandbox.new

    assert @project.update_app
    assert @project.reload.working?
    with_fakes(sandbox) { perform_enqueued_jobs(only: ProjectUpdateJob) }

    @project.reload
    assert @project.ready?
    assert_equal "Update the storefront kit", @project.shell.run("git", "log", "-1", "--format=%s").strip
    assert_not_includes sandbox.commands, [ "bin/rails", "db:migrate" ]
    assert_equal "Updated the storefront kit", @project.messages.where(role: "notice").last.body
    assert_match "vendor/blocks/storefront_kit", @project.agent_note
    assert_match "- Fix checkout", @project.agent_note
    assert_no_enqueued_jobs(only: AgentTurnJob)
  end

  test "when the app's tests fail with the new core, the agent fixes the app" do
    @monorepo.join("blocks/storefront_kit/lib/storefront_kit.rb").write("module StorefrontKit; VERSION = 2; end")
    commit_monorepo "Fix checkout"
    sandbox = FakeSandbox.new
    sandbox.tests_pass = false

    @project.update_app
    with_fakes(sandbox) { perform_enqueued_jobs(only: ProjectUpdateJob) }

    job = enqueued_jobs.find { |enqueued| enqueued["job_class"] == "AgentTurnJob" }
    assert job
    request = ActiveJob::Arguments.deserialize(job["arguments"])[1]
    assert_match "never change vendor/blocks", request
    assert_match "OrdersTest", request
  end

  test "template changes the app changed go to the agent, with their diffs" do
    @project.path.join("app/views/products/show.html.erb").write("<h1 class=peach>Product</h1>\n")
    @project.history.commit("Restyle")
    @monorepo.join("storefront/app/views/products/show.html.erb").write("<h1>Product</h1>\n<%= render 'reviews' %>\n")
    commit_monorepo "Let buyers review what they bought"

    @project.update_app
    with_fakes(FakeSandbox.new) { perform_enqueued_jobs(only: ProjectUpdateJob) }

    assert_equal "Update the new features", @project.shell.run("git", "log", "-1", "--format=%s").strip
    assert_match "the agent is bringing in the rest", @project.messages.where(role: "notice").last.body
    job = enqueued_jobs.find { |enqueued| enqueued["job_class"] == "AgentTurnJob" }
    request = ActiveJob::Arguments.deserialize(job["arguments"])[1]
    assert_match "- Let buyers review what they bought", request
    assert_match "- app/views/products/show.html.erb", request
    assert_match "tmp/template_update/<file>.diff", request
  end

  test "an app that's busy isn't updated" do
    @project.update!(status: :working)
    assert_not @project.update_app
    assert_no_enqueued_jobs(only: ProjectUpdateJob)
  end

  private
    def commit_monorepo(message, at: nil)
      git = ProjectShell.new(@monorepo)
      git.run("git", "init", "--quiet") unless @monorepo.join(".git").exist?
      git.run("git", "add", "--all")
      env = at ? { "GIT_COMMITTER_DATE" => at.iso8601, "GIT_AUTHOR_DATE" => at.iso8601 } : {}
      git.run("git", "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", message, env:)
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
