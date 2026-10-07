require "test_helper"

class AgentTurnJobTest < ActiveSupport::TestCase
  class FakeRunner
    attr_reader :prompts

    def initialize(events = [ { "type" => "result", "num_turns" => 1 } ]) = (@prompts, @events = [], events)

    def run(prompt)
      @prompts << prompt
      @events.each { |event| yield event }
    end
  end

  setup do
    @project = projects(:clinic)
    @runner = FakeRunner.new
  end

  test "a new turn runs the request and remembers which job runs it" do
    job = AgentTurnJob.new(@project, "Thêm trang báo cáo", "plan")
    with_runner { job.perform_now }

    assert_equal [ "Thêm trang báo cáo" ], @runner.prompts
    assert_equal job.job_id, @project.reload.agent_job_id
    assert @project.ready?
  end

  test "a turn checks in on the project while it runs, and stops when it ends" do
    seen = nil
    project = @project
    @runner.define_singleton_method(:run) { |prompt, &block| seen = project.reload.slice(:turn_heartbeat_at, :turn_worker_pid) }

    with_runner { AgentTurnJob.perform_now(@project, "Thêm trang báo cáo", "plan") }

    assert seen["turn_heartbeat_at"].present?
    assert_equal Process.pid, seen["turn_worker_pid"]
    assert_nil @project.reload.turn_heartbeat_at
    assert_nil @project.turn_worker_pid
  end

  test "an agent that ends without finishing its turn is an error, not a success" do
    @runner = FakeRunner.new([ { "type" => "system", "subtype" => "init", "session_id" => "abc" } ])

    with_runner { AgentTurnJob.perform_now(@project, "Thêm trang báo cáo", "plan") }

    assert @project.reload.failed?
    assert_equal "The agent stopped without finishing its turn.", @project.messages.error.last.body
  end

  test "a turn cut off by a restart resumes where it left off" do
    job = AgentTurnJob.new(@project, "Thêm trang báo cáo", "plan")
    @project.update!(status: :working, agent_job_id: job.job_id, working_since: 1.minute.ago, activity: "Thinking")

    with_runner { job.perform_now }

    assert_equal 1, @runner.prompts.size
    assert @runner.prompts.first.start_with?(AgentTurnJob::RESUME_NOTE)
    assert @runner.prompts.first.end_with?("Thêm trang báo cáo")
    assert_match "restarted", @project.messages.notice.last.body
  end

  test "a cut-off turn the owner had stopped doesn't start again" do
    job = AgentTurnJob.new(@project, "Thêm trang báo cáo", "plan")
    @project.update!(status: :working, agent_job_id: job.job_id, working_since: 1.minute.ago)
    @project.agent_commands.create!(kind: :interrupt)

    with_runner { job.perform_now }

    assert_empty @runner.prompts
    assert @project.reload.ready?
  end

  test "a turn that ends with questions waits for the answers without committing" do
    @runner = FakeRunner.new([ { "type" => "builder_ask", "id" => "toolu_1", "questions" => [ { "question" => "Khách có cần tài khoản không?", "options" => [] } ] } ])
    @project.define_singleton_method(:history) { raise "committed" }

    with_runner { AgentTurnJob.perform_now(@project, "Làm trang đặt lịch", "build") }

    assert @project.reload.ready?
    assert_nil @project.activity
    assert @project.messages.assistant.last.data["questions"].present?
  end

  test "a finished build remembers the version it left, to go back to from the chat" do
    root = Pathname(Dir.mktmpdir)
    original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, root
    @project.path.mkpath
    @project.shell.run("git", "init", "--quiet")
    @project.shell.run("git", "commit", "--quiet", "--allow-empty", "-m", "Set up")
    @project.define_singleton_method(:restart_preview) { |**| }
    @runner = FakeRunner.new([ { "type" => "result", "total_cost_usd" => 0.5, "num_turns" => 3 } ])
    @runner.define_singleton_method(:run) { |prompt, &block| @prompts << prompt; File.write(File.join(Rails.configuration.x.projects_root, "nha-khoa", "app.rb"), "v1"); @events.each(&block) }

    with_runner { AgentTurnJob.perform_now(@project, "Thêm trang báo cáo", "build") }

    assert_equal @project.history.current_sha, @project.messages.result.last.data["sha"]
    assert_equal @project.history.current_tree, @project.messages.result.last.data["tree"]
    assert_equal "Thêm trang báo cáo", @project.history.versions.first.subject
  ensure
    Rails.configuration.x.projects_root = original_root
    FileUtils.rm_rf(root)
  end

  private
    def with_runner
      runner = @runner
      AgentRunner.singleton_class.alias_method :original_new, :new
      AgentRunner.define_singleton_method(:new) { |*, **| runner }
      yield
    ensure
      AgentRunner.singleton_class.alias_method :new, :original_new
      AgentRunner.singleton_class.remove_method :original_new
    end
end
