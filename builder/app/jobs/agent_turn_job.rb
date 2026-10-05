# One round of the owner's request: the agent works in the project, every step
# shows up in the chat, then the result is committed and the preview restarted.
class AgentTurnJob < ApplicationJob
  def perform(project, request)
    project.update!(status: :working)
    AgentRunner.new(project).run(request) { |event| AgentEvent.new(project, event).record }
    finish(project, request)
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end

  private
    def finish(project, request)
      project.shell.run("bin/rails", "tailwindcss:build")
      commit(project, request)
      project.preview.restart
      project.update!(status: :ready, preview_version: project.preview_version + 1)
    end

    def commit(project, request)
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", request.squish.truncate(72)) unless project.shell.run("git", "status", "--porcelain").blank?
    end
end
