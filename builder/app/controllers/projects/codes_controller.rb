# The Code tab: the project's files, the ones the latest turn changed first, and one file open.
class Projects::CodesController < ApplicationController
  def show
    @project = find_project(params[:project_id])
    @code = @project.code
    @path = params[:path].presence || default_path
    @source = @code.read(@path) if @path && @code.changes[@path] != "deleted"
  end

  private
    def default_path
      @code.changes.find { |_path, status| status != "deleted" }&.first ||
        [ "config/routes.rb", "README.md" ].find { |path| @code.paths.include?(path) } || @code.paths.first
    end
end
