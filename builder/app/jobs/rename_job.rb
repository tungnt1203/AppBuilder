# Puts the app's new name in its code as a version of its own, so the preview shows
# it and the agent knows.
class RenameJob < ApplicationJob
  def perform(project)
    project.write_app_name
    project.history.commit("Rename the app to #{project.name}")
    project.restart_preview
    project.update!(status: :ready,
      agent_note: [ project.agent_note, "The owner renamed the app to “#{project.name}” (config.x.app_name)." ].compact.join("\n\n"))
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end
end
