# The storefront's words and photos the owner changes in the studio's Design tab: its text and
# image settings (config/theme_settings.yml), saved as the shop's values, the same ones Settings
# → Theme in the admin keeps. The preview reads them at once; so does the live shop.
class ProjectContent
  FILE = "config/theme_settings.yml"
  TYPES = %w[ text richtext image ]

  Field = Data.define(:key, :type, :label, :default)

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

        Field.new(key: raw["key"].to_s, type: raw["type"].to_s, label: raw["label"].to_s.presence || raw["key"].to_s.humanize, default: raw["default"])
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

  private
    def setting
      @setting ||= ActsAsTenant.with_tenant(@project.shop) { ThemeSetting.current }
    end
end
