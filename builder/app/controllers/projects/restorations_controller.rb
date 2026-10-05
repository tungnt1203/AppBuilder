class Projects::RestorationsController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_id])

    if project.accepts_messages?
      project.update!(status: :working)
      RestoreJob.perform_later(project, params.expect(:sha))
    end

    redirect_to project
  end
end
