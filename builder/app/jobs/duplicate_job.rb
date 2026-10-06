# Copies another project's folder (code, git history, the preview's database and
# uploads) into a new project, then names it and starts its preview. Safe to run
# again if the job process restarted halfway.
class DuplicateJob < ApplicationJob
  def perform(copy, source)
    copy_files(source, copy)
    copy.write_app_name
    copy.history.commit("Copy “#{source.name}” as #{copy.name}")
    FileUtils.cp(source.thumbnail.path, copy.thumbnail.path) if source.thumbnail.exist?
    copy.restart_preview(restart: false)
    copy.messages.create!(role: :notice, body: "Copied from “#{source.name}”: its code, versions and preview data.")
    copy.update!(status: :ready)
  rescue ProjectShell::Error => error
    copy.messages.create!(role: :error, body: error.message.truncate(4000))
    copy.update!(status: :failed)
  end

  private
    # Into a side folder first, so a half-done copy is never taken for a finished one.
    # The source's running server (tmp/pids) and logs stay behind.
    def copy_files(source, copy)
      return if copy.path.exist?

      partial = copy.path.sub_ext(".partial")
      FileUtils.rm_rf(partial)
      ProjectShell.new(source.path).run("rsync", "-a", "--exclude=/tmp/", "--exclude=/log/", "./", "#{partial}/")
      partial.join("tmp/pids").mkpath
      partial.join("log").mkpath
      partial.rename(copy.path)
    end
end
