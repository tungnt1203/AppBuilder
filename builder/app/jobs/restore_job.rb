# Puts an earlier version of the project's code back, then brings the preview up
# on it. The agent is told on its next turn, since the files changed under it.
class RestoreJob < ApplicationJob
  def perform(project, sha)
    version = project.history.find(sha)
    project.history.restore(version)
    project.restart_preview

    project.messages.create!(role: :notice, body: "Restored “#{version.subject}”")
    project.update!(status: :ready,
      agent_note: "Since your last turn the owner restored the app to an earlier version (“#{version.subject}”). " \
                  "Re-read any file before you change it.")
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end
end
