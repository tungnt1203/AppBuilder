# Where apps come from: the template's last commit, in the repository it's in (a folder of the
# monorepo, or a repository of its own), and the blocks (blocks/shop…) it links from
# vendor/blocks/, of which an app gets a real copy (see ProjectSetupJob). Apps are brought up to
# later versions of both (ProjectBlocks, ProjectTemplate). A block's version is its git tree hash:
# the same files have the same hash in the repository and in an app's own repository.
class TemplateSource
  def initialize(template_path = Rails.configuration.x.template_path)
    @template_path = Pathname(template_path)
    @template = ProjectShell.new(@template_path)
  end

  # { "shop" => "blocks/shop" }: each block the template links to, by its path in the repository.
  def paths
    @paths ||= @template_path.glob("vendor/blocks/*").select(&:symlink?).to_h do |link|
      [ link.basename.to_s, Pathname(folder).join("vendor/blocks", link.readlink).cleanpath.to_s ]
    end
  end

  def names
    paths.keys
  end

  # The block's version in the repository's last commit.
  def tree(name)
    repository.run("git", "rev-parse", "HEAD:#{paths.fetch(name)}").strip
  end

  # Writes the block's files from the last commit into directory (which is emptied first).
  def extract(name, into:)
    into = Pathname(into)
    FileUtils.rm_rf(into)
    into.mkpath
    Tempfile.create([ "block", ".tar" ]) do |archive|
      repository.run("git", "archive", "--format=tar", "--output", archive.path, "HEAD:#{paths.fetch(name)}")
      ProjectShell.new(into).run("tar", "-xf", archive.path)
    end
  end

  # What changed in the block since the version with this tree hash, newest first: the subjects
  # of the commits after it. Nil when the version isn't one of the repository's (changed by hand).
  def changes_since(name, tree, limit: 100)
    path = paths.fetch(name)
    commits = repository.run("git", "log", "--format=%H%x1f%s", "-n", limit.to_s, "--", path).lines.map { |line| line.chomp.split("\x1f", 2) }
    return [] if commits.empty?

    # The block's tree after each of those commits, in one call.
    trees = repository.run("git", "rev-parse", *commits.map { |sha, _| "#{sha}:#{path}" }).lines.map(&:strip)
    index = trees.index(tree)
    commits.first(index).map(&:last) if index
  rescue ProjectShell::Error
    nil
  end

  # The repository's last commit: the template version new apps start from.
  def head
    repository.run("git", "rev-parse", "HEAD").strip
  end

  # The last commit made before time: the version an app made then started from.
  def commit_before(time)
    repository.run("git", "rev-list", "-1", "--before=#{time.iso8601}", "HEAD").strip.presence
  end

  # Template files changed between two commits, as [status, path in the app] with status "A"
  # (added), "M" or "D" (deleted); a renamed file is one deleted and one added.
  def changed_files(from, to = head)
    repository.run("git", "diff", "--name-status", "--no-renames", from, to, "--", folder.presence || ".").lines.filter_map do |line|
      status, path = line.chomp.split("\t", 2)
      [ status[0], path.delete_prefix(folder) ] if path
    end
  end

  # A template file's bytes at a commit, nil when it isn't there.
  def file(commit, path)
    output, found = repository.capture("git", "cat-file", "blob", "#{commit}:#{folder}#{path}")
    output.b if found
  end

  def executable?(commit, path)
    repository.run("git", "ls-tree", commit, "--", "#{folder}#{path}").start_with?("100755")
  end

  # What changed in one template file between two commits, as a diff of the template's paths.
  def diff(from, to, path)
    repository.run("git", "diff", "--no-renames", from, to, "--", "#{folder}#{path}")
  end

  # The subjects of the commits that changed the template between two commits, newest first.
  def subjects(from, to = head, limit: 50)
    repository.run("git", "log", "--format=%s", "-n", limit.to_s, "#{from}..#{to}", "--", folder.presence || ".").lines.map(&:chomp)
  end

  # The repository's root: git archive only sees paths from there.
  def repository
    @repository ||= ProjectShell.new(@template.run("git", "rev-parse", "--show-toplevel").strip)
  end

  # The template's folder in the repository ("template/"), empty when it's a repository of its own.
  def folder
    @folder ||= @template.run("git", "rev-parse", "--show-prefix").strip
  end
end
