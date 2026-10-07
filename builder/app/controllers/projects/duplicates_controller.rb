class Projects::DuplicatesController < ApplicationController
  def create
    project = find_project(params[:project_id])
    project.duplicate unless project.busy?

    redirect_to root_path
  end
end
