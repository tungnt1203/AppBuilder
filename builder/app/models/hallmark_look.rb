# The looks an owner can start a shop from on the studio's home: Hallmark themes (the template's
# .claude/skills/hallmark/references/themes) that suit a shop, each with the picture of a page
# built in it. Picked, it goes with the first request ("Use the Sticker look"), and the agent puts
# it in place as the storefront's material instead of dealing one.
class HallmarkLook
  # Shop-friendly ones, from calm to loud; the rest stay for the agent's own deals.
  SLUGS = %w[ coral editorial loom garden bloom hum squeeze riso sticker halftone carnival kiln darkroom ].freeze

  attr_reader :slug, :name, :material

  def self.all
    SLUGS.filter_map { |slug| find(slug) }
  end

  def self.find(slug)
    return unless SLUGS.include?(slug.to_s)

    file = folder.join("#{slug}.md")
    return unless file.file?

    header = file.read[/\A---\n(.*?)\n---/m, 1].to_s.lines.to_h { |line| line.chomp.split(": ", 2) }
    new(slug.to_s, header.fetch("name", slug.to_s.titleize), header["material"].to_s)
  end

  def self.folder
    Rails.configuration.x.template_path.join(".claude/skills/hallmark/references/themes")
  end

  def initialize(slug, name, material)
    @slug, @name, @material = slug, name, material
  end

  def picture = self.class.folder.join("#{slug}.jpg").then { |file| file if file.file? }

  # What the first request says, for the owner to read in the chat and the agent to act on.
  def request_line = "Use the #{name} look (Hallmark's #{slug} material)."

  def to_param = slug
end
