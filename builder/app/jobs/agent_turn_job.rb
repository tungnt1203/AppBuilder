# One round of the owner's request: the agent works in the project, every step
# shows up in the chat, then the result is committed and the preview restarted.
class AgentTurnJob < ApplicationJob
  def perform(project, request)
    project.update!(status: :working)
    AgentRunner.new(project).run(request) { |event| AgentEvent.new(project, event).record }
    finish(project, request, status: :ready)
  rescue ProjectShell::Error => error
    # The agent usually reported why it stopped (for example a usage limit); only add
    # the raw error when it didn't.
    project.messages.create!(role: :error, body: error.message.truncate(4000)) unless project.messages.last&.error?
    finish(project, "Unfinished: #{request}", status: :failed)
  end

  private
    # Keep whatever the agent changed, even after a failure, so it can be undone or continued.
    def finish(project, request, status:)
      project.shell.run("bin/rails", "tailwindcss:build")
      commit(project, request)
      project.preview.restart
      project.update!(status: status, preview_version: project.preview_version + 1)
    rescue ProjectShell::Error => error
      project.messages.create!(role: :error, body: error.message.truncate(4000))
      project.update!(status: :failed)
    end

    def commit(project, request)
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", request.squish.truncate(72)) unless project.shell.run("git", "status", "--porcelain").blank?
    end
end
