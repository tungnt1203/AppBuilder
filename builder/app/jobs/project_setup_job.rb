# Copies the template into a new project, configures its name, time zone and
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
      project.adopt_name(AppNamer.new(request).name) if project.name_pending?
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
      copy_blocks(repository, folder, project)
      project.shell.run("git", "init", "--quiet", "--initial-branch=main")
      project.shell.run("git", "add", "--all")
      project.shell.run("git", "commit", "--quiet", "-m", "Start from the template")
    end

    # The template uses the blocks (blocks/shop…) through symlinks in vendor/blocks/; the app gets a
    # real copy of each, from the same commit, since its sandbox and Docker image only see its folder.
    def copy_blocks(repository, folder, project)
      project.path.glob("vendor/blocks/*").select(&:symlink?).each do |link|
        source = Pathname(folder).join("vendor/blocks", link.readlink).cleanpath
        link.delete
        link.mkpath
        Tempfile.create([ "block", ".tar" ]) do |archive|
          repository.run("git", "archive", "--format=tar", "--output", archive.path, "HEAD:#{source}")
          ProjectShell.new(link).run("tar", "-xf", archive.path)
        end
      end
    end

    def configure(project)
      return if project.base_sha

      project.write_app_name
      application = project.path.join("config/application.rb")
      application.write(localize(application.read, project))
      project.shell.run("git", "commit", "--quiet", "-am", "Set up #{project.name}")
      project.update!(base_sha: project.history.current_sha)
    end

    # Apps are in English whatever the owner's language (which is only the one they chat in);
    # they get the owner's time zone, for order times in /admin.
    def localize(source, project)
      source.sub(/^(\s*)config\.time_zone = ".*"$/) { %(#{$1}config.time_zone = "#{project.time_zone}") }
    end
end
