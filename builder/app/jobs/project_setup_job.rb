# Copies the template into a new project, configures its name, time zone and
# time zone, starts the preview, then hands the owner's first request (already in
# the chat) to the agent. Safe to run again if the job process restarted halfway.
class ProjectSetupJob < ApplicationJob
  def perform(project, first_request = nil, mode = "plan")
    name(project)
    copy_template(project)
    project.ensure_shop!
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
    # From the owner's own words, not the notes about attached files the agent gets with them.
    def name(project)
      return unless project.name_pending?

      request = project.messages.user.first&.body
      project.adopt_name(request.present? ? AppNamer.new(request).name : nil)
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
      copy_blocks(project)
      project.update!(template_sha: repository.run("git", "rev-parse", "HEAD").strip)
      project.shell.run("git", "init", "--quiet", "--initial-branch=main")
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", "Start from the template")
    end

    # The template uses the blocks (blocks/storefront_kit) through symlinks in vendor/blocks/; the app gets a
    # real copy of each, from the same commit, since its sandbox and Docker image only see its folder.
    def copy_blocks(project)
      source = TemplateSource.new
      source.names.each { |name| source.extract(name, into: project.path.join("vendor/blocks", name)) }
    end

    def configure(project)
      return if project.base_sha

      project.write_app_name
      application = project.path.join("config/application.rb")
      application.write(localize(application.read, project))
      # A storefront has nothing to set here (its name is its shop's), but the version is still its base.
      project.shell.run("git", "commit", "--quiet", "--allow-empty", "-am", "Set up #{project.name}")
      project.update!(base_sha: project.history.current_sha)
    end

    # Apps are in English whatever the owner's language (which is only the one they chat in);
    # they get the owner's time zone, for order times in /admin.
    def localize(source, project)
      source.sub(/^(\s*)config\.time_zone = ".*"$/) { %(#{$1}config.time_zone = "#{project.time_zone}") }
    end
end
