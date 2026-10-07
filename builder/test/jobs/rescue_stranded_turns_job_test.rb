require "test_helper"

class RescueStrandedTurnsJobTest < ActiveSupport::TestCase
  class FakeStrandedJob
    attr_reader :retried
    def retry = @retried = true
  end

  setup do
    @project = projects(:shop) # working
    @stranded = FakeStrandedJob.new
    stranded = @stranded
    StrandedJob.singleton_class.alias_method :original_find, :find
    StrandedJob.define_singleton_method(:find) { |active_job_id| stranded if active_job_id == "job-1" }
  end

  teardown do
    StrandedJob.singleton_class.alias_method :find, :original_find
    StrandedJob.singleton_class.remove_method :original_find
  end

  test "runs a turn again when the worker running it is gone" do
    @project.update!(agent_job_id: "job-1", turn_heartbeat_at: 30.seconds.ago, turn_worker_pid: dead_pid)

    RescueStrandedTurnsJob.perform_now
    assert @stranded.retried
  end

  test "runs a turn again when it stopped checking in long ago" do
    @project.update!(agent_job_id: "job-1", turn_heartbeat_at: 11.minutes.ago, turn_worker_pid: Process.pid)

    RescueStrandedTurnsJob.perform_now
    assert @stranded.retried
  end

  test "leaves a turn whose worker is still there: it finishes by itself" do
    @project.update!(agent_job_id: "job-1", turn_heartbeat_at: 3.minutes.ago, turn_worker_pid: Process.pid)

    RescueStrandedTurnsJob.perform_now
    assert_not @stranded.retried
  end

  test "leaves projects that aren't in a turn" do
    @project.update!(status: :ready, agent_job_id: "job-1", turn_heartbeat_at: 1.hour.ago, turn_worker_pid: dead_pid)
    projects(:clinic).update!(status: :working, agent_job_id: "job-1", turn_heartbeat_at: nil) # restoring, renaming…

    RescueStrandedTurnsJob.perform_now
    assert_not @stranded.retried
  end

  private
    def dead_pid
      pid = Process.spawn("true")
      Process.wait(pid)
      pid
    end
end
