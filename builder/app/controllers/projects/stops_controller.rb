class Projects::StopsController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_id])

    if project.working? && !project.stop_requested?
      AgentRunner.stop(project)
      project.messages.create!(role: :notice, body: "Stopped. What's done so far is kept.")
    end

    redirect_to project
  end
end
