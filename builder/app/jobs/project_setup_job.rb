# Copies the template into a new project, configures its name, language and
# time zone, starts the preview, then hands the owner's first request (already in
# the chat) to the agent.
class ProjectSetupJob < ApplicationJob
  def perform(project, first_request = nil)
    copy_template(project)
    configure(project)
    prepare(project)
    project.preview.start
    project.update!(status: :ready, preview_version: project.preview_version + 1)

    AgentTurnJob.perform_later(project, first_request) if first_request.present?
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end

  private
    def copy_template(project)
      project.path.dirname.mkpath
      ProjectShell.new(project.path.dirname).run("git", "clone", "--quiet", Rails.configuration.x.template_path.to_s, project.path.to_s)
      project.shell.run("git", "remote", "remove", "origin")
    end

    def configure(project)
      application = project.path.join("config/application.rb")
      application.write(application.read
        .sub(/config\.x\.app_name = ".*"/) { %(config.x.app_name = #{project.name.inspect}) }
        .sub(/config\.i18n\.default_locale = :\w+/, "config.i18n.default_locale = :#{project.language}")
        .sub(/config\.time_zone = ".*"/) { %(config.time_zone = "#{project.time_zone}") })
      project.shell.run("git", "commit", "--quiet", "-am", "Set up #{project.name}")
    end

    def prepare(project)
      project.shell.run("bundle", "install", "--quiet")
      project.shell.run("bin/rails", "db:prepare")
      project.shell.run("bin/rails", "tailwindcss:build")
    end
end
