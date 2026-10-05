class ProjectsController < ApplicationController
  before_action :set_project, only: :show

  def index
    @projects = Project.ordered
    @project = Project.new(language: "vi")
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      request = params.dig(:project, :request).to_s.strip
      @project.messages.create!(role: :user, body: request) if request.present?
      ProjectSetupJob.perform_later(@project, request.presence)
      redirect_to @project
    else
      @projects = Project.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def show
    PreviewStartJob.perform_later(@project) if @project.ready? && !@project.preview.running?
  end

  private
    def set_project
      @project = Project.find_by!(slug: params[:id])
    end

    def project_params
      params.expect(project: [ :name, :language ])
    end
end
