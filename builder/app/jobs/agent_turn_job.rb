# One round of the owner's request. In "plan" mode the agent only reads and
# proposes (or asks); in "build" mode it changes the app, and the result is
# committed and the preview restarted. Every step shows up in the chat.
class AgentTurnJob < ApplicationJob
  def perform(project, request, mode = "build")
    prompt = [ project.agent_note, request ].compact.join("\n\n")
    project.update!(status: :working, planning: mode == "plan", agent_note: nil, working_since: Time.current, activity: "Starting")
    transcript = AgentTranscript.new(project)

    AgentRunner.new(project, mode:).run(prompt) { |event| transcript.record(event) }
    transcript.finish

    if mode == "plan"
      propose(project)
    else
      finish(project, project.take_commit_message || request, status: :ready)
    end
  rescue ProjectShell::Error => error
    transcript&.finish
    # The agent usually reported why it stopped (for example a usage limit); only add
    # the raw error when it didn't.
    project.messages.create!(role: :error, body: error.message.truncate(4000)) unless project.messages.last&.error?
    mode == "plan" ? project.update!(status: :failed, activity: nil) : finish(project, "Unfinished: #{project.take_commit_message || request}", status: :failed)
  end

  private
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
