# The owner updates the app's blocks (the shop core…) to the latest, see BlockUpdateJob.
class Projects::BlockUpdatesController < ApplicationController
  def create
    find_project(params[:project_id]).update_blocks
    redirect_to project_path(params[:project_id])
  end
end
