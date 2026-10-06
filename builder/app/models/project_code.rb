# The project's files as the owner reads them in the Code tab, and which ones the
# latest turn changed. Before a turn is committed (while the agent works) that is
# the working tree against HEAD; afterwards, the latest version against the one
# before it. Only files git knows about (or would add) can be read.
class ProjectCode
  MAX_BYTES = 300.kilobytes
  STATUSES = { "A" => "added", "M" => "changed", "D" => "deleted" }

  Source = Data.define(:path, :content, :added_lines) do
    def binary? = content.nil?
    def lines = content.to_s.lines
  end

  def initialize(project)
    @project = project
  end

  def paths
    @paths ||= git("ls-files", "--cached", "--others", "--exclude-standard", "-z").split("\0").uniq.sort
  end

  # Path => "added", "changed" or "deleted".
  def changes
    @changes ||= begin
      tracked = base ? git("diff", "--name-status", "--no-renames", "-z", base).split("\0").each_slice(2).to_h { |status, path| [ path, STATUSES.fetch(status[0], "changed") ] } : {}
      untracked = git("ls-files", "--others", "--exclude-standard", "-z").split("\0").index_with("added")
      tracked.merge(untracked).sort.to_h
    end
  end

  # Folders as nested hashes ending in file paths: { "app" => { "models" => { "user.rb" => "app/models/user.rb" } } }.
  def tree
    paths.each_with_object({}) do |path, root|
      *folders, name = path.split("/")
      folders.reduce(root) { |node, folder| node[folder] ||= {} }[name] = path
    end
  end

  def read(path)
    raise ActiveRecord::RecordNotFound, "No file #{path}" unless paths.include?(path)

    file = @project.path.join(path)
    content = file.read(MAX_BYTES + 1) if file.file?
    content = nil if content.nil? || content.bytesize > MAX_BYTES || !content.force_encoding(Encoding::UTF_8).valid_encoding? || content.include?("\0")
    Source.new(path:, content:, added_lines: content ? added_lines(path) : Set.new)
  end

  private
    # The version the latest turn started from; nil for a project with a single commit.
    def base
      return @base if defined?(@base)

      @base = @project.working? ? "HEAD" : ("HEAD~1" if git("rev-list", "--count", "HEAD").to_i > 1)
    end

    # Line numbers in the current file that the latest turn added or rewrote.
    def added_lines(path)
      return (1..Float::INFINITY) if changes[path] == "added"
      return Set.new unless changes[path] && base

      git("diff", "--unified=0", "--no-color", base, "--", path).scan(/^@@ -\S+ \+(\d+)(?:,(\d+))? @@/).each_with_object(Set.new) do |(start, count), lines|
        lines.merge(start.to_i...(start.to_i + (count || 1).to_i))
      end
    end

    def git(*args)
      @project.shell.run("git", *args)
    end
end
