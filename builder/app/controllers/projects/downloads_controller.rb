# The app's code as a zip, to keep or to work on elsewhere.
class Projects::DownloadsController < ApplicationController
  def show
    project = find_project(params[:project_id])

    Dir.mktmpdir("download") do |dir|
      file = File.join(dir, "#{project.archive_name}.zip")
      project.archive_to(file)
      send_data File.binread(file), filename: File.basename(file), type: "application/zip"
    end
  end
end
