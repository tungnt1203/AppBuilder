# Copies the template into a new project, configures its name, language and
# time zone, starts the preview, then hands the owner's first request (already in
# the chat) to the agent. Safe to run again if the job process restarted halfway.
class ProjectSetupJob < ApplicationJob
  def perform(project, first_request = nil, mode = "plan")
    name(project, first_request)
    copy_template(project)
    configure(project)
    project.sandbox.run("bundle", "install", "--quiet")
    project.restart_preview(restart: false)
    project.update!(status: :ready)

    AgentTurnJob.perform_later(project, first_request, mode) if first_request.present?
  rescue ProjectShell::Error => error
    project.messages.create!(role: :error, body: error.message.truncate(4000))
    project.update!(status: :failed)
  end

  private
    def name(project, request)
      project.adopt_name(AppNamer.new(request, language: project.language).name) if project.name_pending?
    end

    # The template's last commit (not unsaved edits) becomes the app's first version. The
    # template is a folder of a bigger repository (the monorepo) or a repository of its own.
    def copy_template(project)
      return if project.path.join(".git").exist?

      template = ProjectShell.new(Rails.configuration.x.template_path)
      repository = ProjectShell.new(template.run("git", "rev-parse", "--show-toplevel").strip) # archive only sees the root's view
      folder = template.run("git", "rev-parse", "--show-prefix").strip
      project.path.mkpath
      Tempfile.create([ "template", ".tar" ]) do |archive|
        repository.run("git", "archive", "--format=tar", "--output", archive.path, "HEAD:#{folder}")
        project.shell.run("tar", "-xf", archive.path)
      end
      project.shell.run("git", "init", "--quiet", "--initial-branch=main")
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", "Start from the template")
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
