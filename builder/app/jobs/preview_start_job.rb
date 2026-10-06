# Starts a project's preview again: after the builder restarted, or when the owner
# asks to try a broken preview again.
class PreviewStartJob < ApplicationJob
  def perform(project, restart: false)
    project.restart_preview(restart: restart)
  end
end
