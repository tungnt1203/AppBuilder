# The owner approves the proposed plan and the agent builds it.
class Projects::BuildsController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_id])
    project.ask(project.approval_message, mode: "build") if project.accepts_messages? && project.latest_proposal

    redirect_to project
  end
end
