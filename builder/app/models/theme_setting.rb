# The storefront's theme declares its settings (config/theme_settings.yml). Publish applies that
# schema here (apply_schema!); values the owner already saved are kept when the field is still
# the same type. The admin edits values only. The API returns each field merged with its default.
class ThemeSetting < ApplicationRecord
  acts_as_tenant :shop

  TYPES = %w[ text richtext image color url boolean select ].freeze
  KEY = /\A[a-z][a-z0-9_]{0,40}\z/
  MAX_IMAGE_SIZE = 8.megabytes

  has_many_attached :images

  def self.current
    first || new
  end

  # definitions: [{ "key", "type", "label", "default", "options" }], as the theme's yaml parses.
  # A field that changed type, or a select value no longer offered, loses its saved value.
  def self.apply_schema!(definitions, version: nil)
    record = current
    fields = normalize_schema(definitions)
    kept = record.values.stringify_keys.slice(*fields.map { |field| field["key"] })
    fields.each do |field|
      previous = record.schema_field(field["key"])
      drop = previous.nil? || previous["type"] != field["type"]
      drop ||= field["type"] == "select" && !field["options"].include?(kept[field["key"]])
      kept.delete(field["key"]) if drop
    end
    if record.persisted?
      removed = record.schema.map { |field| field["key"] } - fields.map { |field| field["key"] }
      changed = fields.filter_map { |field| field["key"] if (previous = record.schema_field(field["key"])) && previous["type"] != field["type"] }
      (removed + changed).each { |key| record.image_attachment(key)&.purge }
    end
    record.update!(schema: fields, schema_version: version, values: kept)
    record
  end

  def self.normalize_schema(definitions)
    Array(definitions).filter_map { |raw| field_from(raw.respond_to?(:stringify_keys) ? raw.stringify_keys : {}) }
      .uniq { |field| field["key"] }
  end

  def schema_field(key)
    schema.find { |field| field["key"] == key }
  end

  def image_attachment(key)
    images.detect { |attachment| attachment.blob.metadata["setting_key"] == key }
  end

  # Every declared field, with the owner's value or the theme's default. image_url, given an
  # attachment, returns the URL the storefront should use.
  def resolved(image_url: nil)
    schema.each_with_object({}) do |field, out|
      key = field["key"]
      out[key] = case field["type"]
      when "boolean" then values.key?(key) ? values[key] == true : field["default"] == true
      when "image" then (image_attachment(key)&.then { |attachment| image_url&.call(attachment) }) || field["default"]
      else values[key].presence || field["default"]
      end
    end
  end

  def update_values(raw_values, uploads: {}, removals: [])
    errors.clear
    proposed = values.stringify_keys
    schema.each do |field|
      key = field["key"]
      next if field["type"] == "image"

      raw = raw_values.to_h.stringify_keys[key]
      if field["type"] == "boolean"
        proposed[key] = ActiveModel::Type::Boolean.new.cast(raw) == true
      elsif raw.blank?
        proposed.delete(key)
      elsif (problem = value_problem(field, raw))
        errors.add(:base, "#{field["label"]}: #{problem}")
      else
        proposed[key] = raw.to_s
      end
    end
    Array(removals).each do |key|
      next unless schema_field(key)&.fetch("type") == "image"

      proposed.delete(key)
    end
    check_uploads(uploads)
    return false if errors.any?

    self.values = proposed
    transaction do
      save!
      Array(removals).each { |key| image_attachment(key)&.purge }
      uploads.to_h.each do |key, file|
        next if file.blank?

        image_attachment(key)&.purge
        images.attach(io: file, filename: file.original_filename.presence || "image", content_type: file.content_type, metadata: { "setting_key" => key })
      end
    end
    true
  end

  def self.field_from(raw)
    key = raw["key"].to_s
    type = raw["type"].to_s
    return unless key.match?(KEY) && TYPES.include?(type)

    field = { "key" => key, "type" => type, "label" => raw["label"].to_s.squish.presence || key.humanize }
    if type == "select"
      options = Array(raw["options"]).map { |option| option.to_s.strip }.compact_blank.uniq
      return if options.empty?

      field["options"] = options
    end
    default = default_for(type, raw["default"], field["options"])
    field["default"] = default unless default.nil?
    field
  end

  def self.default_for(type, value, options)
    case type
    when "boolean" then ActiveModel::Type::Boolean.new.cast(value) == true
    when "color" then value.to_s if value.to_s.match?(/\A#[0-9a-fA-F]{6}\z/)
    when "url", "image" then value.to_s if value.to_s.match?(/\Ahttps?:\/\/\S+\z/)
    when "select" then value.to_s if options&.include?(value.to_s)
    when "text", "richtext" then value.to_s.presence
    end
  end

  private
    def value_problem(field, raw)
      text = raw.to_s
      case field["type"]
      when "color" then "use a color like #e8743b" unless text.match?(/\A#[0-9a-fA-F]{6}\z/)
      when "url" then "use a full https address" unless text.match?(/\Ahttps?:\/\/\S+\z/)
      when "select" then "pick one of the choices" unless field["options"].include?(text)
      when "text" then "is too long" if text.length > 500
      when "richtext" then "is too long" if text.length > 5_000
      end
    end

    def check_uploads(uploads)
      uploads.to_h.each do |key, file|
        next if file.blank?

        field = schema_field(key)
        unless field&.fetch("type") == "image" && file.content_type.to_s.start_with?("image/") && file.size <= MAX_IMAGE_SIZE
          errors.add(:base, "#{field&.fetch("label") || key} must be an image under 8 MB")
        end
      end
    end
end
