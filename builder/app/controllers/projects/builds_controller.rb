# The owner approves the proposed plan and the agent builds it.
class Projects::BuildsController < ApplicationController
  def create
    project = find_project(params[:project_id])
    project.ask(project.approval_message, mode: "build") if project.accepts_messages? && project.latest_proposal

    redirect_to project
  end
end
