# Polled by the chat while a project is setting up or working: says so when no worker is picking
# up the background jobs, instead of a clock that runs while nothing happens.
class Projects::WorkerChecksController < ApplicationController
  def show
    @project = find_project(params[:project_id])
    @running = JobWorker.running?
  end
end
