class Projects::DeploymentsController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_id])
    project.publish if project.publishable?

    redirect_to project
  end
end
