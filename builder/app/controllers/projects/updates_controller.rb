# The owner brings the app up to the latest blocks and template, see ProjectUpdateJob.
class Projects::UpdatesController < ApplicationController
  def create
    find_project(params[:project_id]).update_app
    redirect_to project_path(params[:project_id])
  end
end
