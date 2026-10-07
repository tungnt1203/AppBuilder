# Retakes the picture on the app's card once its preview is up on new code.
class ThumbnailJob < ApplicationJob
  limits_concurrency to: 1, key: ->(project) { project }, duration: 1.minute
  discard_on ActiveJob::DeserializationError

  def perform(project)
    project.broadcast_listing if project.preview_running? && project.thumbnail.capture
  end
end
