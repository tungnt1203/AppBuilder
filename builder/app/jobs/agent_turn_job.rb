# One round of the owner's request. In "plan" mode the agent only reads and
# proposes (or asks); in "build" mode it changes the app, and the result is
# committed and the preview restarted. Every step shows up in the chat.
#
# If the job process restarts mid-turn, Solid Queue runs the job again; the agent
# then resumes its session and continues instead of starting over. If the worker dies
# or is given up on, RescueStrandedTurnsJob runs it again the same way; the turn checks
# in on the project (turn_heartbeat_at, turn_worker_pid) so it can tell.
class AgentTurnJob < ApplicationJob
  RESUME_NOTE = "The builder restarted while you were working on this and your turn was cut off. " \
                "Check what is already done before you continue."
  HEARTBEAT = 15 # seconds

  around_perform :check_in

  def perform(project, request, mode = "build")
    if project.agent_job_id == job_id
      return unless resume_interrupted(project, request, mode)
      request = [ RESUME_NOTE, request ].join("\n\n")
    end

    prompt = [ project.agent_note, request ].compact.join("\n\n")
    project.update!(status: :working, planning: mode == "plan", agent_note: nil, working_since: Time.current, activity: "Starting", agent_job_id: job_id)
    project.agent_commands.pending.where.not(kind: :message).update_all(delivered_at: Time.current) # left from an earlier turn
    transcript = AgentTranscript.new(project)

    AgentRunner.new(project, mode:, config: agent_config(project)).run(prompt) { |event| transcript.record(event) }
    transcript.finish
    unless transcript.finished? || transcript.asked? || project.stop_requested?
      raise ProjectShell::Error, "The agent stopped without finishing its turn."
    end

    if transcript.asked?
      wait_for_answers(project)
    elsif mode == "plan"
      propose(project)
    else
      finish(project, project.take_commit_message || request, status: :ready)
    end
    continue_with_late_messages(project)
  rescue ProjectShell::Error => error
    transcript&.finish
    # The agent usually reported why it stopped (for example a usage limit); only add
    # the raw error when it didn't.
    project.messages.create!(role: :error, body: error.message.truncate(4000)) unless project.messages.last&.error?
    mode == "plan" ? project.update!(status: :failed, activity: nil) : finish(project, "Unfinished: #{project.take_commit_message || request}", status: :failed)
  end

  private
    def check_in
      project = arguments.first
      checks_in = Project.where(id: project.id)
      checks_in.update_all(turn_heartbeat_at: Time.current, turn_worker_pid: ::Process.pid)
      heartbeat = Thread.new do
        loop do
          sleep HEARTBEAT
          Rails.application.executor.wrap { checks_in.update_all(turn_heartbeat_at: Time.current) }
        end
      end

      yield
      StrandedJob.settle(job_id) # given up on by Solid Queue while it was still working
    ensure
      heartbeat&.kill
      checks_in&.where(turn_worker_pid: ::Process.pid)&.update_all(turn_heartbeat_at: nil, turn_worker_pid: nil)
    end

    # Clears what the cut-off run left behind. Returns false when the owner had
    # already pressed Stop, so the turn ends here with its work kept.
    def resume_interrupted(project, request, mode)
      AgentRunner.end_leftover(project)
      AgentTranscript.new(project).finish

      if project.stop_requested?
        mode == "plan" ? project.update!(status: :ready, activity: nil) : finish(project, "Unfinished: #{project.take_commit_message || request}", status: :ready)
        false
      else
        project.messages.create!(role: :notice, body: "The builder restarted during this step. Picking up where it left off.")
        true
      end
    end

    # The summary of this turn remembers the version it left, so the owner can go back to it from the chat.
    def mark_version(project)
      summary = project.messages.where(role: %w[ result error ], created_at: project.working_since..).last
      summary&.update!(data: summary.data.merge("sha" => project.history.current_sha, "tree" => project.history.current_tree))
    end

    # Messages the owner sent while the agent was finishing up become the next turn.
    def continue_with_late_messages(project)
      late = project.agent_commands.message.pending.to_a
      return if late.empty? || project.stop_requested?

      AgentCommand.where(id: late).update_all(delivered_at: Time.current)
      project.update!(status: :working)
      AgentTurnJob.perform_later(project, late.map { |command| command.payload["text"] }.join("\n\n"), "build")
    end

    # The agent asked the owner something; their answers start the next turn, in the same
    # session. Work done so far is committed with the turn that finishes it.
    def wait_for_answers(project)
      project.update!(status: :ready, activity: nil)
    end

    # A plan reply without questions is a proposal the owner can approve.
    def propose(project)
      reply = project.messages.assistant.last
      reply.update!(data: reply.data.merge("proposal" => true)) if reply && reply.data["questions"].blank?
      project.update!(status: :ready, activity: nil)
    end

    # Keep whatever the agent changed, even after a failure, so it can be undone or continued.
    # A turn may spend what's left of the owner's monthly budget, up to the per-turn limit.
    def agent_config(project)
      config = Rails.configuration.x.agent
      left = project.owner&.budget_left
      left ? config.merge(max_budget_usd: [ config[:max_budget_usd].to_f, left ].min.round(2)) : config
    end

    def finish(project, message, status:)
      project.adopt_app_name_from_code
      project.history.commit(message)
      mark_version(project)
      project.update!(activity: "Restarting the preview")
      project.restart_preview
      project.update!(status: status, planning: false, activity: nil)
    rescue ProjectShell::Error => error
      project.messages.create!(role: :error, body: error.message.truncate(4000))
      project.update!(status: :failed)
    end
end
