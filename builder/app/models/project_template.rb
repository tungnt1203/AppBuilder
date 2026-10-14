# The template's changes since an app's code was made from it (new features' screens, fixes, the
# agent's instructions), brought into the app (ProjectUpdateJob). Like a three-way merge: a file
# the app never changed takes the template's new version as it is; a file the app changed (its own
# design) is left for the agent, with the template's diff of it in tmp/template_update/.
class ProjectTemplate
  # The app's own, or made from the app's code: never taken from the template.
  IGNORED = %r{\A(vendor/blocks/|storage/|log/|tmp/|db/schema\.rb\z|SPEC\.md\z|DESIGN\.md\z)}
  DIFFS = "tmp/template_update"

  Result = Data.define(:updated, :left) do
    def left? = left.any?
  end

  def initialize(project, source = TemplateSource.new)
    @project, @source = project, source
  end

  # The template commit the app's code is from.
  def base
    @base ||= @project.template_sha.presence || setup_commit
  end

  def head
    @head ||= @source.head
  end

  # Template files with changes the app doesn't have yet.
  def files
    return [] unless base && base != head

    @files ||= @source.changed_files(base, head).reject { |_status, path| path.match?(IGNORED) }
  rescue ProjectShell::Error
    []
  end

  def outdated?
    files.any?
  end

  # What's new, newest first: the subjects of the template's commits since the app's version.
  def changes
    @changes ||= outdated? ? @source.subjects(base, head) : []
  end

  # Takes every change it can, writes the diffs of the rest for the agent, and moves the app to
  # the template's latest version.
  def apply!
    updated, left = [], []
    diffs = @project.path.join(DIFFS)
    FileUtils.rm_rf(diffs)

    files.each do |_status, path|
      old, new = @source.file(base, path), @source.file(head, path)
      target = @project.path.join(path)
      current = target.file? ? target.binread : nil

      if current == new
        next
      elsif current == old
        new ? write(target, new, executable: @source.executable?(head, path)) : target.delete
        updated << path
      else
        diffs.join("#{path}.diff").tap { |file| file.dirname.mkpath }.write(@source.diff(base, head, path))
        left << path
      end
    end

    @project.update!(template_sha: head)
    @base, @files, @changes = head, nil, nil
    Result.new(updated:, left:)
  end

  private
    # An app made before the builder kept its template commit started from the last one before
    # its first version.
    def setup_commit
      first = @project.shell.run("git", "log", "--reverse", "--format=%cI").lines.first
      @source.commit_before(Time.iso8601(first.strip)) if first
    rescue ProjectShell::Error
      nil
    end

    def write(target, bytes, executable:)
      target.dirname.mkpath
      target.binwrite(bytes)
      target.chmod(executable ? 0o755 : 0o644)
    end
end
