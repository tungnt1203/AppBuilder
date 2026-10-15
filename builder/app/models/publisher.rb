# Publishes a project to ONCE: build and push the image, back up the running
# version, then deploy or update. ONCE keeps the old version running when the
# new one fails its health check, so a failed publish never takes the app down.
class Publisher
  def initialize(deployment, once: Rails.configuration.x.once_bin)
    @deployment, @project, @once = deployment, deployment.project, once
  end

  def publish
    @deployment.update!(commit_sha: @project.shell.run("git", "rev-parse", "--short", "HEAD").strip)
    first = first_publish?
    run_steps(build_steps)
    @deployment.deploying!
    run_steps(deploy_steps)
    @deployment.live!
    announce_first_publish if first
  rescue ProjectShell::Error => error
    @deployment.append_log(error.message)
    @deployment.failed!
  end

  def build_steps
    [ [ "docker", "build", "--tag", @deployment.image, "." ],
      [ "docker", "push", @deployment.image ] ]
  end

  def deploy_steps
    if first_publish?
      [ [ @once, "deploy", @deployment.image, "--host", @project.publish_host, "--auto-update=false" ] ]
    else
      [ [ @once, "backup", @project.publish_host, backup_path.to_s ],
        [ @once, "update", @project.publish_host, "--image", @deployment.image ] ]
    end
  end

  private
    # The published app starts with no accounts; tell the owner where to create theirs.
    def announce_first_publish
      @project.messages.create!(role: :notice, body: "Published at #{@project.publish_url}. " \
        "Create your owner account at #{@project.publish_url}#{@project.staff_sign_in_path} before sharing it.")
    end

    def first_publish?
      !@project.deployments.live.where.not(id: @deployment.id).exists?
    end

    def backup_path
      Rails.configuration.x.backups_root.join(@project.slug).tap(&:mkpath).join("before-v#{@deployment.version}.tar.gz")
    end

    def run_steps(steps)
      steps.each do |command|
        @deployment.append_log("$ #{command.join(" ")}\n")
        @deployment.append_log(@project.shell.run(*command).last(4000))
      end
    end
end
