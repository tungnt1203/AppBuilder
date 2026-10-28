# The storefront's layouts (themes/<name>/ in the template, close copies of Shopify themes that
# sell), the Hallmark material over them, and switching layouts from the studio's Design tab, the way the template's
# bin/theme does: the theme's header, footer, home page, product card and theme.css over the
# app's. A file changed for this shop since a theme put it there is listed first, since the
# switch replaces it (History still has it).
class ProjectTheme
  Theme = Data.define(:name, :summary, :current, :changed)
  Material = Data.define(:slug, :name, :summary)
  CSS = "app/assets/tailwind/theme.css"
  FONTS = "app/views/layouts/_fonts.html.erb"

  def initialize(project)
    @project = project
  end

  def available?
    root.directory? && themes.any?
  end

  # The one in use is the theme most of the app's files still match; `changed` when some of them
  # were changed for this shop since.
  def themes
    @themes ||= begin
      folders = root.children.select(&:directory?).sort
      matches = folders.to_h { |folder| [ folder, matching(folder) ] }
      in_use, count = matches.max_by { |_, matched| matched }
      folders.map do |folder|
        readme = folder.join("README.md")
        summary = readme.file? ? readme.read[/\A# [^\n]*\n\n(.+?)\n\n/m, 1].to_s.squish : ""
        current = folder == in_use && count.positive?
        Theme.new(name: folder.basename.to_s, summary:, current:, changed: current && count < files(folder).size)
      end
    end
  end

  def current
    themes.find(&:current)
  end

  # The app's files a switch to this theme would replace that no theme has as they are now.
  def changed_files(name)
    files(folder(name)).map { |file| file.relative_path_from(folder(name)).to_s }.select do |path|
      target = @project.path.join(path)
      target.file? && root.children.select(&:directory?).none? { |other| other.join(path).file? && other.join(path).read == target.read }
    end
  end

  # The Hallmark theme the storefront's look is made of (bin/theme material), named in theme.css.
  def material
    slug = css.file? && css.read[/bin\/theme material ([\w-]+)/, 1]
    file = slug && @project.path.join(".claude/skills/hallmark/references/themes/#{slug}.md")
    return unless file&.file?

    header = file.read[/\A---\n(.*?)\n---/m, 1].to_s.lines.to_h { |line| line.chomp.split(": ", 2) }
    Material.new(slug:, name: header.fetch("name", slug.titleize), summary: header["material"].to_s)
  end

  # Another layout. A storefront with a material keeps it (its theme.css, with what the agent
  # added, and its fonts): only the new layout's page width comes along.
  def switch(name)
    folder(name) # an unknown theme is not found
    kept = [ css.read, fonts.read ] if material && fonts.file?
    @project.sandbox.run("bin/theme", name, "--force")
    if kept
      width = css.read[/--page-width:\s*([^;]+);/, 1]
      css.write(kept.first.sub(/--page-width:\s*[^;]+;/) { "--page-width: #{width};" }.sub(/shape: \w+ layout/, "shape: #{name} layout"))
      fonts.write(kept.last)
    end
    @project.history.commit("Layout: #{name}")
    @project.sandbox.run("bin/rails", "tailwindcss:build")
  end

  private
    def css = @project.path.join(CSS)
    def fonts = @project.path.join(FONTS)

    def root
      @project.path.join("themes")
    end

    def folder(name)
      themes.map(&:name).include?(name.to_s) ? root.join(name.to_s) : raise(ActiveRecord::RecordNotFound, "No theme #{name}")
    end

    def files(folder)
      folder.glob("**/*").select(&:file?).reject { |file| file.basename.to_s == "README.md" }
    end

    def matching(folder)
      files(folder).count { |file| (target = @project.path.join(file.relative_path_from(folder))).file? && target.read == file.read }
    end
end
