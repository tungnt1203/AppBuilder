# Chats with the agent: start a new one (a new Claude session, the app as it is), or go back
# to an earlier one, whose next turn resumes its session. Not while the agent is busy.
class Projects::ChatsController < ApplicationController
  before_action :set_project

  def create
    @project.start_chat unless @project.busy?
    redirect_to @project
  end

  def update
    @project.switch_chat(@project.chats.find(params[:id])) unless @project.busy?
    redirect_to @project
  end

  private
    def set_project
      @project = find_project(params[:project_id])
    end
end
