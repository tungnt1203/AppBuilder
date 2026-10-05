class Projects::MessagesController < ApplicationController
  def create
    @project = Project.find_by!(slug: params[:project_id])
    request = params.dig(:message, :body).to_s.strip

    if @project.accepts_messages? && request.present?
      @project.ask(request, mode: params.dig(:message, :plan) == "1" ? "plan" : "build")
    end

    redirect_to @project
  end
end
