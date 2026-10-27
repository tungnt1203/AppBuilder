class Projects::StopsController < ApplicationController
  def create
    project = find_project(params[:project_id])
    project.stop
    redirect_to project
  end
end
