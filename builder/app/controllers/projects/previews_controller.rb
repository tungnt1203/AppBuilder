class Projects::PreviewsController < ApplicationController
  # The preview, for whoever may see the project: through its gate with a fresh ticket.
  def show
    project = find_project(params[:project_id])
    redirect_to project.preview_gate.entry_url, allow_other_host: true
  end

  # "Try again" on a preview that failed to come up: restart it on the current code.
  def create
    project = find_project(params[:project_id])

    if project.accepts_messages? && !project.preview_starting?
      project.update!(preview_status: :starting, preview_error: nil)
      PreviewStartJob.perform_later(project, restart: true)
    end

    redirect_to project
  end
end
