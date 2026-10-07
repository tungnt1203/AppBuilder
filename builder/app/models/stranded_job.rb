# A job Solid Queue gave up on because the worker running it looked dead: it missed its
# heartbeats for too long (the computer slept, the process hung) and was pruned, or it
# crashed. Solid Queue marks such a job failed and never runs it again, even when its
# thread is in fact still working.
class StrandedJob
  PROCESS_ERRORS = %w[ SolidQueue::Processes::ProcessPrunedError SolidQueue::Processes::ProcessMissingError SolidQueue::Processes::ProcessExitError ]

  def self.find(active_job_id)
    return unless solid_queue?

    failed = SolidQueue::FailedExecution.joins(:job).find_by(job: { active_job_id: active_job_id })
    new(failed) if failed && PROCESS_ERRORS.include?(failed.exception_class)
  end

  # A job that finished its work after all shouldn't stay listed as failed.
  def self.settle(active_job_id)
    find(active_job_id)&.finish
  end

  def self.solid_queue?
    ActiveJob::Base.queue_adapter_name == "solid_queue"
  end

  def initialize(failed_execution)
    @failed_execution = failed_execution
  end

  # Runs it again, with the same job id.
  def retry
    @failed_execution.retry
  end

  def finish
    job = @failed_execution.job
    @failed_execution.destroy!
    job.finished!
  end
end
