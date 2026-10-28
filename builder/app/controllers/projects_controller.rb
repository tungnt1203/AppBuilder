class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show update destroy ]

  def index
    set_listing
    @project = Project.new(language: "en")
  end

  def create
    request = params.dig(:project, :request).to_s.strip
    # A look picked on the home goes with the request, in words the owner reads in the chat.
    if (look = HallmarkLook.find(params.dig(:project, :look))) && (request.present? || Array(params.dig(:project, :files)).compact_blank.any?)
      request = [ request.presence, look.request_line ].compact.join("\n\n")
    end
    files = Array(params.dig(:project, :files)).compact_blank
    @project = Current.user.projects.new(project_params)
    @project.name_after(request.presence || ("New app" if files.any?))

    if @project.save
      prompt = @project.record_request(request, files:) if request.present? || files.any?
      ProjectSetupJob.perform_later(@project, prompt.presence, params.dig(:project, :plan) == "1" ? "plan" : "build")
      redirect_to @project
    else
      set_listing
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @project.ensure_preview
  end

  def update
    @project.rename(params.expect(project: [ :name ])[:name]) unless @project.busy?
    redirect_back_or_to root_path
  end

  def destroy
    @project.remove unless @project.busy?
    redirect_to root_path, status: :see_other
  end

  private
    # Administrators can list every account's apps.
    def set_listing
      @everyone = Current.user.administrator? && params[:apps] == "all"
      @projects = (@everyone ? Project.all : Current.user.projects).listed.ordered.includes(:owner)
    end

    def set_project
      @project = find_project(params[:id])
    end

    def project_params
      params.expect(project: [ :name, :language ])
    end
end
