require "test_helper"

class AgentTurnJobTest < ActiveSupport::TestCase
  class FakeRunner
    attr_reader :prompts

    def initialize(events = []) = (@prompts, @events = [], events)

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
