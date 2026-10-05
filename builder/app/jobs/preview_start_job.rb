# Starts a project's preview again, for example after the builder restarted.
class PreviewStartJob < ApplicationJob
  def perform(project)
    project.preview.start
    project.update!(preview_version: project.preview_version + 1)
  end
end
