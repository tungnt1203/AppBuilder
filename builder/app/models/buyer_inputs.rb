# Text the buyer types on a product ("Name on the shirt", at most 20 characters). The product
# stores the definitions; the cart line stores what they typed, and the order carries it to Printify.
#
# A field can also show the text on the product's photos as the buyer types (its "preview"): a box
# on the photos where it sits (fractions of the photo, so any size of it), the photos it shows on
# (a back view doesn't), its font and color, and the fonts and colors the buyer may pick instead,
# which come with the line as "<key>_font" and "<key>_color".
class BuyerInputs
  KEY = /\A[a-z][a-z0-9_]{0,40}\z/
  MAX_FIELDS = 10
  MAX_LENGTH = 80
  # The same families in the admin, the storefront and (later) the print file.
  FONTS = [ "Baloo 2", "Bebas Neue", "Bricolage Grotesque", "Caveat", "Dancing Script", "Fraunces", "Great Vibes", "Lobster",
            "Lora", "Montserrat", "Nunito", "Oswald", "Pacifico", "Permanent Marker", "Playfair Display", "Quicksand",
            "Roboto Slab", "Space Grotesk" ].freeze
  ALIGNS = %w[ left center right ].freeze
  COLOR = /\A#\h{6}\z/
  MAX_CHOICES = 8

  def self.definitions(rows)
    used = []
    Array(rows).filter_map { |row|
      row = row.to_h.stringify_keys
      label = row["label"].to_s.squish
      next if label.blank?

      key = row["key"].to_s.parameterize(separator: "_").presence || label.parameterize(separator: "_")
      next unless key.match?(KEY) && used.exclude?(key)

      used << key
      length = row["max_length"].to_i
      length = 40 unless (1..MAX_LENGTH).cover?(length)
      { "key" => key, "label" => label.first(80), "required" => ActiveModel::Type::Boolean.new.cast(row["required"]) == true, "max_length" => length,
        "preview" => preview(row["preview"]) }.compact
    }.first(MAX_FIELDS)
  end

  # Where and how the text shows on the photos, or nil when it doesn't (no box drawn).
  def self.preview(raw)
    raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    raw = raw.stringify_keys
    box = %w[ x y w h ].to_h { |side| [ side, raw[side].to_f.clamp(0.0, 1.0).round(4) ] }
    return if box["w"] < 0.02 || box["h"] < 0.02

    box["w"] = [ box["w"], 1 - box["x"] ].min.round(4)
    box["h"] = [ box["h"], 1 - box["y"] ].min.round(4)
    font = FONTS.include?(raw["font"]) ? raw["font"] : FONTS.first
    color = raw["color"].to_s.downcase.match?(COLOR) ? raw["color"].to_s.downcase : "#111111"
    fonts = (Array(raw["fonts"]) & FONTS).first(MAX_CHOICES)
    colors = Array(raw["colors"]).flat_map { |value| value.to_s.split(/[\s,]+/) }.map(&:downcase).grep(COLOR).uniq.first(MAX_CHOICES)
    box.merge(
      "images" => Array(raw["images"]).map(&:to_i).select(&:positive?).uniq,
      "font" => font, "fonts" => (fonts.size > 1 ? (fonts | [ font ]) : []),
      "color" => color, "colors" => (colors.size > 1 ? (colors | [ color ]) : []),
      "align" => ALIGNS.include?(raw["align"]) ? raw["align"] : "center",
      "uppercase" => ActiveModel::Type::Boolean.new.cast(raw["uppercase"]) == true
    )
  end

  # [properties, nil] when what the buyer typed fits, or [nil, { "print_name" => "can't be blank" }].
  # The font and color they picked come along when the field lets them pick.
  def self.accept(definitions, raw)
    raw = case raw
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    else {}
    end.stringify_keys
    errors = {}
    properties = {}
    Array(definitions).each do |field|
      value = raw[field["key"]].to_s.strip
      if value.blank?
        errors[field["key"]] = "can't be blank" if field["required"]
      elsif value.length > field["max_length"]
        errors[field["key"]] = "is too long (maximum is #{field["max_length"]} characters)"
      else
        properties[field["key"]] = value
        properties.merge!(choices(field, raw))
      end
    end
    errors.empty? ? [ properties, nil ] : [ nil, errors ]
  end

  def self.choices(field, raw)
    preview = field["preview"] or return {}
    { "font" => preview["fonts"], "color" => preview["colors"] }.each_with_object({}) do |(kind, allowed), picked|
      value = raw["#{field["key"]}_#{kind}"].to_s
      value = value.downcase if kind == "color"
      picked["#{field["key"]}_#{kind}"] = value if allowed.to_a.include?(value)
    end
  end
  private_class_method :choices

  # The text on the photo for a cart or order line: each field that shows on photos, with what the
  # buyer typed in the font and color they picked. Empty when nothing shows.
  def self.layers(definitions, properties)
    properties = properties.to_h.stringify_keys
    Array(definitions).filter_map do |field|
      preview, text = field["preview"], properties[field["key"]]
      next if preview.blank? || text.blank?

      preview.slice("x", "y", "w", "h", "images", "align", "uppercase").merge("text" => text,
        "font" => properties["#{field["key"]}_font"].presence_in(preview["fonts"].to_a) || preview["font"],
        "color" => properties["#{field["key"]}_color"].presence_in(preview["colors"].to_a) || preview["color"])
    end
  end
end
