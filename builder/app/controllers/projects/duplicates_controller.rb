class Projects::DuplicatesController < ApplicationController
  def create
    project = find_project(params[:project_id])
    project.duplicate(owner: Current.user) unless project.busy? || Current.user.app_limit_reached?

    redirect_to root_path
  end
end
