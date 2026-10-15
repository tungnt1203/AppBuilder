# The blocks an app has a copy of (vendor/blocks/shop…), compared with the template's. Fixes and
# improvements to a block reach an app when its owner updates it (BlockUpdateJob): the copy is
# replaced by the latest one, as a version of its own in the app's history.
class ProjectBlocks
  # Shown to the owner, by block.
  TITLES = { "shop" => "shop core" }.freeze

  def initialize(project, source = TemplateSource.new)
    @project, @source = project, source
  end

  # Blocks with a newer version than the app's: { "shop" => ["Fix …", "Let buyers …"] }, the
  # changes newest first (empty when the app's copy isn't a version from the repository).
  def updates
    @updates ||= @source.names.each_with_object({}) do |name, updates|
      current = tree(name)
      next if current.nil? || current == @source.tree(name)

      updates[name] = @source.changes_since(name, current).to_a
    end
  rescue ProjectShell::Error
    {}
  end

  def outdated?
    updates.any?
  end

  # "shop core", or several joined: "shop core and payments block"
  def titles(names = updates.keys)
    names.map { |name| TITLES.fetch(name, "#{name} block") }.to_sentence
  end

  # Replaces the app's copy of each outdated block with the latest. Returns their names.
  def update!
    names = updates.keys
    names.each { |name| @source.extract(name, into: @project.path.join("vendor/blocks", name)) }
    @updates = nil
    names
  end

  private
    # The app's committed copy; nil for a block it doesn't have (apps made before it existed).
    def tree(name)
      output, ok = @project.shell.capture("git", "rev-parse", "HEAD:vendor/blocks/#{name}")
      output.strip if ok
    end
end
