# Where apps get their blocks (blocks/shop…): the template links each one from vendor/blocks/,
# and an app gets a real copy of it, from the last commit of the repository the template is in
# (see ProjectSetupJob and ProjectBlocks). A block's version is its git tree hash: the same files
# have the same hash in the repository and in an app's own repository.
class BlockSource
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

  # The repository's root: git archive only sees paths from there.
  def repository
    @repository ||= ProjectShell.new(@template.run("git", "rev-parse", "--show-toplevel").strip)
  end

  # The template's folder in the repository ("template/"), empty when it's a repository of its own.
  def folder
    @folder ||= @template.run("git", "rev-parse", "--show-prefix").strip
  end
end
