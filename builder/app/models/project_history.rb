# A project's versions are the commits in its git repository since it was set up.
# Restoring adds a new commit with an earlier version's files, so nothing is lost
# and the restore itself can be undone.
class ProjectHistory
  Version = Data.define(:sha, :subject, :committed_at)
  SEPARATOR = "\x1f"

  def initialize(project)
    @project = project
  end

  def versions(limit: 30)
    return [] unless @project.path.join(".git").exist?

    range = @project.base_sha ? [ "#{@project.base_sha}~1..HEAD" ] : []
    shell.run("git", "log", "--format=%h#{SEPARATOR}%s#{SEPARATOR}%cI", "-n", limit.to_s, *range).lines.map do |line|
      sha, subject, time = line.chomp.split(SEPARATOR, 3)
      Version.new(sha:, subject:, committed_at: Time.iso8601(time))
    end
  rescue ProjectShell::Error
    [] # still being copied from the template, no commits yet
  end

  def current_sha
    shell.run("git", "rev-parse", "--short", "HEAD").strip
  end

  # The files of the current version: a restore makes a new version with the same files.
  def current_tree
    shell.run("git", "rev-parse", "--short", "HEAD^{tree}").strip
  rescue ProjectShell::Error
    nil
  end

  def find(sha)
    versions(limit: 200).find { |version| version.sha == sha } or raise ActiveRecord::RecordNotFound, "No version #{sha}"
  end

  # Keeps every change in the working tree as one version, if there is any.
  def commit(message)
    shell.run("git", "add", "--all")
    shell.run("git", "commit", "--quiet", "-m", message.squish.truncate(72)) unless shell.run("git", "status", "--porcelain").blank?
  end

  def restore(version)
    shell.run("git", "restore", "--source", version.sha, "--staged", "--worktree", ":/")
    shell.run("git", "commit", "--quiet", "--allow-empty", "-m", "Restore “#{version.subject.truncate(56)}”")
  end

  private
    def shell
      @project.shell
    end
end
