# Copies the template into a new project, configures its name, language and
# time zone, starts the preview, then hands the owner's first request (already in
# the chat) to the agent. Safe to run again if the job process restarted halfway.
class ProjectSetupJob < ApplicationJob
  def perform(project, first_request = nil, mode = "plan")
    copy_template(project)
    configure(project)
    project.shell.run("bundle", "install", "--quiet")
    project.restart_preview(restart: false)
    project.update!(status: :ready)

    AgentTurnJob.perform_later(project, first_request, mode) if first_request.present?
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end

  private
    def copy_template(project)
      return if project.path.join(".git").exist?

      project.path.dirname.mkpath
      ProjectShell.new(project.path.dirname).run("git", "clone", "--quiet", Rails.configuration.x.template_path.to_s, project.path.to_s)
      project.shell.run("git", "remote", "remove", "origin")
    end

    def configure(project)
      return if project.base_sha

      project.write_app_name
      application = project.path.join("config/application.rb")
      application.write(application.read
        .sub(/config\.i18n\.default_locale = :\w+/, "config.i18n.default_locale = :#{project.language}")
        .sub(/config\.time_zone = ".*"/) { %(config.time_zone = "#{project.time_zone}") })
      project.shell.run("git", "commit", "--quiet", "-am", "Set up #{project.name}")
      project.update!(base_sha: project.history.current_sha)
    end
end
