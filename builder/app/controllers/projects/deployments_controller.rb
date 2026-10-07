class Projects::DeploymentsController < ApplicationController
  def create
    project = find_project(params[:project_id])
    project.publish if project.publishable?

    redirect_to project
  end
end
