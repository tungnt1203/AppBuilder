# What the buyer adds to a product to have it printed, field by field: a line of text ("Name on
# the shirt", at most 20 characters), a photo (kind "photo": a family photo on a mug), one of the
# shop's pictures (kind "choice": their dog's breed, from the product's artwork or from one of the
# shop's sets of pictures, ClipartSet, as "set") or a background
# color (kind "color"). The product stores the definitions; the cart line stores what the buyer
# added (a photo's BuyerUpload token, a picture's artwork id, a color), and the order carries it
# to Printify.
#
# A field can also show on the product's photos as the buyer adds it (its "preview"): a box on the
# photos where it sits (fractions of the photo, so any size of it) and the photos it shows on (a
# back view doesn't). Fields are laid in order, so a background color goes first. Text has a font
# and color, and the fonts and colors the buyer may pick instead, which come with the line as
# "<key>_font" and "<key>_color". A photo fills its box, and how the buyer framed it comes as
# "<key>_crop": "zoom,x,y" (zoom from 1, the point kept in view), and the look the buyer picks among
# the shop's filters (black and white, sepia) as "<key>_filter". Text can bend along an arc ("curve",
# in degrees: up for an arch, down for a smile) or be a monogram (three letters, the middle one big).
# A picture fits its box. A color fills it, from the colors the shop offers. A star map (kind
# "starmap") is the night sky over a city on a day the buyer picks (the value "2014-06-21T22:00",
# the city as "<key>_place": Personalization::Sky), in the shop's colors for the sky and the stars.
#
# A field prints on the front unless the owner says the back ("side"), for a photo on the front and
# a name on the back; each side has its print area (Product#print_areas).
#
# Several photos (a collage) are several photo fields: drawing one box with a layout ("2x1": two
# across) splits it into a field per cell.
class BuyerInputs
  KEY = /\A[a-z][a-z0-9_]{0,40}\z/
  KINDS = %w[ text photo choice color starmap ].freeze
  LAYOUTS = { "1x1" => [ 1, 1 ], "2x1" => [ 2, 1 ], "1x2" => [ 1, 2 ], "3x1" => [ 3, 1 ], "2x2" => [ 2, 2 ], "3x2" => [ 3, 2 ] }.freeze
  MAX_FIELDS = 12
  MAX_LENGTH = 80
  # The same families in the admin, the storefront and (later) the print file.
  FONTS = [ "Baloo 2", "Bebas Neue", "Bricolage Grotesque", "Caveat", "Dancing Script", "Fraunces", "Great Vibes", "Lobster",
            "Lora", "Montserrat", "Nunito", "Oswald", "Pacifico", "Permanent Marker", "Playfair Display", "Quicksand",
            "Roboto Slab", "Space Grotesk" ].freeze
  ALIGNS = %w[ left center right ].freeze
  COLOR = /\A#\h{6}\z/
  MAX_CHOICES = 8
  MAX_OPTIONS = 40
  MAX_ZOOM = 4
  STYLES = %w[ plain monogram ].freeze
  FILTERS = %w[ original bw sepia ].freeze
  MAX_CURVE = 180
  GAP = 0.03 # between a layout's cells, as a share of the box

  def self.definitions(rows)
    used = []
    Array(rows).flat_map { |row| split(row.to_h.stringify_keys) }.filter_map { |row|
      label = row["label"].to_s.squish
      next if label.blank?

      key = row["key"].to_s.parameterize(separator: "_").presence || label.parameterize(separator: "_")
      next unless key.match?(KEY) && used.exclude?(key)

      used << key
      kind = KINDS.include?(row["kind"]) ? row["kind"] : "text"
      length = row["max_length"].to_i
      length = 40 unless (1..MAX_LENGTH).cover?(length)
      { "key" => key, "label" => label.first(80), "kind" => kind,
        "required" => ActiveModel::Type::Boolean.new.cast(row["required"]) == true, "max_length" => (length if kind == "text"),
        "options" => (Array(row["options"]).map(&:to_i).select(&:positive?).uniq.first(MAX_OPTIONS) if kind == "choice"),
        "set" => (row["set"].to_i if kind == "choice" && row["set"].to_i.positive?),
        "preview" => preview(row["preview"], kind:) }.compact
    }.first(MAX_FIELDS)
  end

  # A photo field drawn with a layout: a field per cell of its box ("Photo 1", "Photo 2"…).
  def self.split(row)
    columns, rows = LAYOUTS[row["layout"].to_s]
    box = preview(row["preview"], kind: "photo")
    return [ row.except("layout") ] unless row["kind"] == "photo" && box && columns && columns * rows > 1

    width, height = (box["w"] - GAP * box["w"] * (columns - 1)) / columns, (box["h"] - GAP * box["h"] * (rows - 1)) / rows
    (0...rows).flat_map { |down| (0...columns).map { |across| [ across, down ] } }.each_with_index.map do |(across, down), index|
      cell = { "x" => box["x"] + across * (width + GAP * box["w"]), "y" => box["y"] + down * (height + GAP * box["h"]), "w" => width, "h" => height }
      row.except("layout").merge("label" => "#{row["label"].to_s.squish} #{index + 1}", "key" => (row["key"].presence && "#{row["key"]}_#{index + 1}"),
        "preview" => cell.transform_values { |value| value.round(4) }.merge("images" => box["images"]))
    end
  end
  private_class_method :split

  # Where and how it shows on the photos, or nil when it doesn't (no box drawn).
  def self.preview(raw, kind: "text")
    raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    raw = raw.stringify_keys
    box = %w[ x y w h ].to_h { |side| [ side, raw[side].to_f.clamp(0.0, 1.0).round(4) ] }
    return if box["w"] < 0.02 || box["h"] < 0.02

    box["w"] = [ box["w"], 1 - box["x"] ].min.round(4)
    box["h"] = [ box["h"], 1 - box["y"] ].min.round(4)
    box["images"] = Array(raw["images"]).map(&:to_i).select(&:positive?).uniq
    box["side"] = raw["side"] if raw["side"] != "front" && Product::PRINT_POSITIONS.include?(raw["side"]) # front unless said
    colors = Array(raw["colors"]).flat_map { |value| value.to_s.split(/[\s,]+/) }.map(&:downcase).grep(COLOR).uniq
    case kind
    when "photo"
      filters = Array(raw["filters"]) & FILTERS
      box.merge("filters" => filters.size > 1 ? FILTERS & filters : [])
    when "choice" then box
    when "color" then colors.any? ? box.merge("colors" => colors.first(MAX_OPTIONS)) : nil
    when "starmap"
      box.merge("sky" => raw["sky"].to_s.downcase.match?(COLOR) ? raw["sky"].to_s.downcase : "#0b1d3a",
        "ink" => raw["ink"].to_s.downcase.match?(COLOR) ? raw["ink"].to_s.downcase : "#ffffff",
        # The admin's box is "hide the lines" (an unticked box sends nothing); what's kept is "lines".
        "lines" => raw.key?("lines") ? ActiveModel::Type::Boolean.new.cast(raw["lines"]) == true : ActiveModel::Type::Boolean.new.cast(raw["no_lines"]) != true)
    else
      font = FONTS.include?(raw["font"]) ? raw["font"] : FONTS.first
      color = raw["color"].to_s.downcase.match?(COLOR) ? raw["color"].to_s.downcase : "#111111"
      fonts = (Array(raw["fonts"]) & FONTS).first(MAX_CHOICES)
      colors = colors.first(MAX_CHOICES)
      box.merge(
        "font" => font, "fonts" => (fonts.size > 1 ? (fonts | [ font ]) : []),
        "color" => color, "colors" => (colors.size > 1 ? (colors | [ color ]) : []),
        "align" => ALIGNS.include?(raw["align"]) ? raw["align"] : "center",
        "uppercase" => ActiveModel::Type::Boolean.new.cast(raw["uppercase"]) == true,
        "curve" => raw["curve"].to_i.clamp(-MAX_CURVE, MAX_CURVE),
        "style" => STYLES.include?(raw["style"]) ? raw["style"] : "plain"
      )
    end
  end

  # The side of the product a field prints on: "front", or "back" when the owner says so.
  def self.side(field) = field.dig("preview", "side") || "front"

  # [properties, nil] when what the buyer added fits, or [nil, { "print_name" => "can't be blank" }].
  # The font and color they picked come along when the field lets them pick, and a photo's framing.
  def self.accept(definitions, raw)
    raw = case raw
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    else {}
    end.stringify_keys
    errors = {}
    properties = {}
    Array(definitions).each do |field|
      key = field["key"]
      value = raw[key].to_s.strip
      if value.blank?
        errors[key] = "can't be blank" if field["required"]
        next
      end

      case field["kind"]
      when "photo"
        next errors[key] = "isn't a photo you added" unless BuyerUpload.exists?(token: value)

        properties[key] = value
        properties["#{key}_crop"] = crop(raw["#{key}_crop"]).join(",")
        filter = raw["#{key}_filter"].to_s
        properties["#{key}_filter"] = filter if field.dig("preview", "filters").to_a.include?(filter) && filter != "original"
      when "choice"
        next errors[key] = "isn't one of the choices" unless field["options"].to_a.map(&:to_s).include?(value)

        properties[key] = value
      when "color"
        next errors[key] = "isn't one of the colors" unless field.dig("preview", "colors").to_a.include?(value.downcase)

        properties[key] = value.downcase
      when "starmap"
        place = raw["#{key}_place"].to_s
        next errors[key] = "needs a date and one of the places" unless Personalization::Sky.for(value, place)

        properties[key] = value
        properties["#{key}_place"] = place
      else
        if field.dig("preview", "style") == "monogram"
          value = value.gsub(/[^[:alpha:]]/, "").upcase
          next errors[key] = "needs one to three letters" unless value.length.between?(1, 3)
        end
        next errors[key] = "is too long (maximum is #{field["max_length"]} characters)" if value.length > field["max_length"].to_i

        properties[key] = value
        properties.merge!(choices(field, raw))
      end
    end
    errors.empty? ? [ properties, nil ] : [ nil, errors ]
  end

  # [zoom, x, y] from "zoom,x,y": zoom 1 fills the box, the point (x, y) of the photo stays in view.
  def self.crop(value)
    zoom, x, y = value.to_s.split(",").map { |part| Float(part, exception: false) }
    [ (zoom || 1).clamp(1, MAX_ZOOM).round(3), (x || 0.5).clamp(0, 1).round(3), (y || 0.5).clamp(0, 1).round(3) ]
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

  LOOKS = { "bw" => "Black and white", "sepia" => "Sepia" }.freeze

  # What the buyer added, for people to read on a cart or order line, in the order they added it:
  # [{ key, label, value, kind, raw }] ("Name font: Pacifico", "Your photo: Added", "Your photo
  # look: Sepia", "Sky: June 21, 2014, 10:00 PM"). kind is the field's (nil for a font, a color or
  # a look); raw is what's kept (a photo's token, a picture's id, a color's hex code, for links and
  # swatches). How a photo is framed isn't for reading. artwork: the product's pictures by id.
  def self.entries(definitions, properties, artwork: {})
    fields = Array(definitions).index_by { |field| field["key"] }
    properties.to_h.filter_map do |key, raw|
      field, part = fields[key], nil
      field, part = fields[key.delete_suffix("_#{part}")], part if field.nil? && (part = key[/_(font|color|crop|filter|place)\z/, 1])
      next { key:, label: key.humanize, value: raw.to_s, kind: nil, raw: } unless field
      next if part == "crop"

      label = part ? "#{field["label"]} #{{ "filter" => "look", "place" => "city" }.fetch(part, part)}" : field["label"]
      value = case part || field["kind"]
      when "photo" then "Added"
      when "choice" then (art = artwork[raw.to_i]) ? art.filename.base.humanize : raw.to_s
      when "filter" then LOOKS.fetch(raw.to_s, raw.to_s)
      when "place" then Personalization::Sky.cities.dig(raw, "name") || raw.to_s
      when "starmap" then moment(raw)
      else raw.to_s
      end
      { key:, label:, value:, kind: (field["kind"] unless part), raw: }
    end
  end

  # "2014-06-21T22:00" as "June 21, 2014, 10:00 PM" (a day alone as "June 21, 2014").
  def self.moment(value)
    time = Time.strptime(value.to_s, value.to_s.include?("T") ? "%Y-%m-%dT%H:%M" : "%Y-%m-%d")
    time.strftime(value.to_s.include?("T") ? "%B %-d, %Y, %-l:%M %p" : "%B %-d, %Y")
  rescue ArgumentError
    value.to_s
  end

  # What shows on the photo of a cart or order line, in the fields' order: each field that shows on
  # photos, with what the buyer added. Text in the font and color they picked; a photo as its
  # upload's token, framed as they framed it; a picture as its artwork's id; a color. Empty when
  # nothing shows.
  def self.layers(definitions, properties)
    properties = properties.to_h.stringify_keys
    Array(definitions).filter_map do |field|
      preview, value = field["preview"], properties[field["key"]]
      next if preview.blank? || value.blank?

      box = preview.slice("x", "y", "w", "h", "images")
      case field["kind"]
      when "photo"
        box.merge("kind" => "photo", "upload" => value, "crop" => crop(properties["#{field["key"]}_crop"]),
          "filter" => properties["#{field["key"]}_filter"].presence_in(preview["filters"].to_a) || "original")
      when "choice" then box.merge("kind" => "choice", "artwork" => value.to_i)
      when "color" then box.merge("kind" => "color", "color" => value)
      when "starmap" then box.merge(preview.slice("sky", "ink", "lines")).merge("kind" => "starmap", "when" => value, "place" => properties["#{field["key"]}_place"])
      else
        box.merge(preview.slice("align", "uppercase", "curve", "style")).merge("kind" => "text", "text" => value,
          "font" => properties["#{field["key"]}_font"].presence_in(preview["fonts"].to_a) || preview["font"],
          "color" => properties["#{field["key"]}_color"].presence_in(preview["colors"].to_a) || preview["color"])
      end
    end
  end
end
