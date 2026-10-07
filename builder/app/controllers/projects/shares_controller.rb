class Projects::SharesController < ApplicationController
  def create
    project = find_project(params[:project_id])
    project.share_preview
    redirect_to project
  end

  def destroy
    project = find_project(params[:project_id])
    project.stop_sharing
    redirect_to project
  end
end
