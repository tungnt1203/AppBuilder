class Projects::DuplicatesController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_id])
    project.duplicate unless project.busy?

    redirect_to root_path
  end
end
