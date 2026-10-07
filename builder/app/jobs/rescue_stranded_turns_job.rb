# Runs every minute (config/recurring.yml). When the worker running an agent turn died
# (its process is gone, or the turn stopped checking in), Solid Queue has marked the turn
# failed and won't run it again, and the project would stay "working" forever. Running
# the same job again makes AgentTurnJob resume the agent's session where it stopped.
class RescueStrandedTurnsJob < ApplicationJob
  HUNG_AFTER = 10.minutes # without a heartbeat from a worker that is still there

  def perform
    Project.working.where.not(turn_heartbeat_at: nil).where.not(agent_job_id: nil).find_each do |project|
      next unless dead?(project)

      if (job = StrandedJob.find(project.agent_job_id))
        Rails.logger.info "Resuming the stranded turn of #{project.slug} (job #{project.agent_job_id})"
        job.retry
      end
    end
  end

  private
    def dead?(project)
      !worker_alive?(project.turn_worker_pid) || project.turn_heartbeat_at.before?(HUNG_AFTER.ago)
    end

    def worker_alive?(pid)
      return false unless pid

      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
end
