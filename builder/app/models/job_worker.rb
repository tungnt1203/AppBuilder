# Whether a worker (bin/jobs) is picking up background jobs. Setting a project up, the agent's
# turns and the chat's live updates all wait for one, so without it the studio looks stuck.
module JobWorker
  def self.running?
    return true unless Rails.configuration.active_job.queue_adapter == :solid_queue

    SolidQueue::Process.where(kind: "Worker", last_heartbeat_at: SolidQueue.process_alive_threshold.ago..).exists?
  end
end
