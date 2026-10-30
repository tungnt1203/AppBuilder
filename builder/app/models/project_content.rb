# The storefront's words, photos and choices the owner changes in the studio's Design tab: its
# text, image and select settings (config/theme_settings.yml), saved as the shop's values, the same ones Settings
# → Theme in the admin keeps. The preview reads them at once; so does the live shop.
class ProjectContent
  FILE = "config/theme_settings.yml"
  TYPES = %w[ text richtext image select ]

  # options: a select's [label, value] pairs (option_labels in the file names them).
  Field = Data.define(:key, :type, :label, :default, :options)

  attr_reader :errors

  def initialize(project)
    @project = project
    @errors = []
  end

  def available?
    @project.shop.present? && fields.any?
  end

  def fields
    @fields ||= begin
      file = @project.path.join(FILE)
      definitions = file.file? ? Array(YAML.safe_load_file(file)) : []
      definitions.filter_map do |raw|
        next unless raw.is_a?(Hash) && TYPES.include?(raw["type"].to_s) && raw["key"].to_s.match?(ThemeSetting::KEY)

        Field.new(key: raw["key"].to_s, type: raw["type"].to_s, label: raw["label"].to_s.presence || raw["key"].to_s.humanize, default: raw["default"],
          options: ThemeSetting.labelled_options(raw))
      end
    end
  rescue Psych::Exception
    @fields = []
  end

  # What the shop shows for a text field: the owner's value, else the theme's default.
  def text(field)
    setting.values[field.key].presence || field.default.to_s
  end

  # The photo's address for the studio: the owner's upload, else the default link.
  def image(field)
    attachment = setting.image_attachment(field.key)
    attachment ? Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true) : field.default.presence
  end

  # Only what changed is kept; words put back to the default stop overriding it.
  def save(texts: {}, uploads: {})
    changes = fields.each_with_object({}) do |field, out|
      next unless texts.key?(field.key)

      submitted = texts[field.key].to_s.strip
      next if submitted == text(field)

      out[field.key] = submitted == field.default.to_s ? "" : submitted
    end
    uploads = uploads.to_h.compact_blank
    return false.tap { @errors = [ "Nothing changed." ] } if changes.empty? && uploads.empty?

    @setting = nil
    ActsAsTenant.with_tenant(@project.shop) do
      record = ThemeSetting.extend_schema!(YAML.safe_load_file(@project.path.join(FILE)))
      saved = record.change_values(changes, uploads:)
      @errors = record.errors.full_messages unless saved
      saved
    end
  end

  # A stock photo for an image field: the theme's default becomes its address (a version, credited
  # in the app's stock photo credits, as bin/images does), and an upload the owner made for it is
  # dropped so the photo shows.
  def use_photo(key, url:, credit:, page:)
    field = fields.find { |candidate| candidate.key == key && candidate.type == "image" } or raise ActiveRecord::RecordNotFound, "No photo #{key}"
    raise ArgumentError, "Not a photo address" unless url.to_s.match?(%r{\Ahttps://\S+\z})

    file = @project.path.join(FILE)
    file.write(with_default(file.read, key, url))
    raise ArgumentError, "The theme settings didn't take the photo" unless YAML.safe_load_file(file).find { |raw| raw["key"] == key }&.dig("default") == url

    credits = @project.path.join("app/assets/images/stock/CREDITS.md")
    credits.dirname.mkpath
    credits.write("# Stock photos\n\nWhere each photo in the app comes from.\n\n") unless credits.file?
    credits.write("- #{url}: #{credit} (#{page})\n", mode: "a") unless credits.read.include?(url)

    ActsAsTenant.with_tenant(@project.shop) { ThemeSetting.current.image_attachment(key)&.purge } if @project.shop
    @setting = nil
    @project.history.commit("Photo: #{field.label.sub(/\s*\(.*\)\z/, "")}")
  end

  private
    # The yaml with one field's default replaced or added, comments and order kept. Fields are
    # either a block ("- key: hero_image" then indented lines) or one line ("- { key: …, … }").
    def with_default(yaml, key, value)
      quoted = value.to_json
      lines = yaml.lines
      start = lines.index { |line| line.match?(/\A-\s+(\{\s*)?key:\s*["']?#{Regexp.escape(key)}["']?\s*[,}\n]/) } or raise ArgumentError, "No #{key} in the theme settings"
      if lines[start].include?("{")
        line = lines[start]
        lines[start] = line.match?(/\bdefault:/) ? line.sub(/default:\s*("(?:[^"\\]|\\.)*"|'[^']*'|[^,}]*)/, "default: #{quoted}") : line.sub(/\s*\}\s*$/, ", default: #{quoted} }\n")
      else
        finish = (start + 1...lines.size).find { |index| !lines[index].start_with?(" ") && lines[index].strip.present? } || lines.size
        existing = (start + 1...finish).find { |index| lines[index].match?(/\A\s+default:/) }
        if existing
          lines[existing] = lines[existing].sub(/default:.*$/, "default: #{quoted}")
        else
          lines.insert(finish, "  default: #{quoted}\n")
        end
      end
      lines.join
    end

    def setting
      @setting ||= ActsAsTenant.with_tenant(@project.shop) { ThemeSetting.current }
    end
end
