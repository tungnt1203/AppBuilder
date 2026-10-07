# "Try again" on a preview that failed to come up: restart it on the current code.
class Projects::PreviewsController < ApplicationController
  def create
    project = find_project(params[:project_id])

    if project.accepts_messages? && !project.preview_starting?
      project.update!(preview_status: :starting, preview_error: nil)
      PreviewStartJob.perform_later(project, restart: true)
    end

    redirect_to project
  end
end
