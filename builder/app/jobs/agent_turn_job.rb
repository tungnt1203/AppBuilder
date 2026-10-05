# One round of the owner's request: the agent works in the project, every step
# shows up in the chat, then the result is committed and the preview restarted.
class AgentTurnJob < ApplicationJob
  def perform(project, request)
    prompt = [ project.agent_note, request ].compact.join("\n\n")
    project.update!(status: :working, agent_note: nil)

    AgentRunner.new(project).run(prompt) { |event| AgentEvent.new(project, event).record }
    finish(project, project.take_commit_message || request, status: :ready)
  rescue ProjectShell::Error => error
    # The agent usually reported why it stopped (for example a usage limit); only add
    # the raw error when it didn't.
    project.messages.create!(role: :error, body: error.message.truncate(4000)) unless project.messages.last&.error?
    finish(project, "Unfinished: #{project.take_commit_message || request}", status: :failed)
  end

  private
    # Keep whatever the agent changed, even after a failure, so it can be undone or continued.
    def finish(project, message, status:)
      project.shell.run("bin/rails", "tailwindcss:build")
      commit(project, message)
      project.preview.restart
      project.update!(status: status, preview_version: project.preview_version + 1)
    rescue ProjectShell::Error => error
      project.messages.create!(role: :error, body: error.message.truncate(4000))
      project.update!(status: :failed)
    end

    def commit(project, message)
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", message.squish.truncate(72)) unless project.shell.run("git", "status", "--porcelain").blank?
    end
end
