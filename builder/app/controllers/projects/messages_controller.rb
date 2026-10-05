class Projects::MessagesController < ApplicationController
  def create
    @project = Project.find_by!(slug: params[:project_id])
    request = params.dig(:message, :body).to_s.strip

    if @project.accepts_messages? && request.present?
      @project.messages.create!(role: :user, body: request)
      @project.update!(status: :working)
      AgentTurnJob.perform_later(@project, request)
    end

    redirect_to @project
  end
end
