# One round of the owner's request. In "plan" mode the agent only reads and
# proposes (or asks); in "build" mode it changes the app, and the result is
# committed and the preview restarted. Every step shows up in the chat.
#
# If the job process restarts mid-turn, Solid Queue runs the job again; the agent
# then resumes its session and continues instead of starting over.
class AgentTurnJob < ApplicationJob
  RESUME_NOTE = "The builder restarted while you were working on this and your turn was cut off. " \
                "Check what is already done before you continue."

  def perform(project, request, mode = "build")
    if project.agent_job_id == job_id
      return unless resume_interrupted(project, request, mode)
      request = [ RESUME_NOTE, request ].join("\n\n")
    end

    prompt = [ project.agent_note, request ].compact.join("\n\n")
    project.update!(status: :working, planning: mode == "plan", agent_note: nil, working_since: Time.current, activity: "Starting", agent_job_id: job_id)
    project.agent_commands.pending.where.not(kind: :message).update_all(delivered_at: Time.current) # left from an earlier turn
    transcript = AgentTranscript.new(project)

    AgentRunner.new(project, mode:).run(prompt) { |event| transcript.record(event) }
    transcript.finish

    if mode == "plan"
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

    # Messages the owner sent while the agent was finishing up become the next turn.
    def continue_with_late_messages(project)
      late = project.agent_commands.message.pending.to_a
      return if late.empty? || project.stop_requested?

      AgentCommand.where(id: late).update_all(delivered_at: Time.current)
      project.update!(status: :working)
      AgentTurnJob.perform_later(project, late.map { |command| command.payload["text"] }.join("\n\n"), "build")
    end

    # A plan reply without questions is a proposal the owner can approve.
    def propose(project)
      reply = project.messages.assistant.last
      reply.update!(data: reply.data.merge("proposal" => true)) if reply && reply.data["questions"].blank?
      project.update!(status: :ready, activity: nil)
    end

    # Keep whatever the agent changed, even after a failure, so it can be undone or continued.
    def finish(project, message, status:)
      project.shell.run("bin/rails", "tailwindcss:build")
      commit(project, message)
      project.preview.restart
      project.update!(status: status, planning: false, preview_version: project.preview_version + 1, activity: nil)
    rescue ProjectShell::Error => error
      project.messages.create!(role: :error, body: error.message.truncate(4000))
      project.update!(status: :failed)
    end

    def commit(project, message)
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", message.squish.truncate(72)) unless project.shell.run("git", "status", "--porcelain").blank?
    end
end
