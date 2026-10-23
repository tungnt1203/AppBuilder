require "open3"

# The print file of one side of a personalized line: what the buyer added in the fields of that side
# (BuyerInputs.layers, BuyerInputs.side), drawn where the owner placed it on the product's photo and
# moved onto Printify's print area of the side (Product#print_areas, drawn on that photo), at the
# print area's size, on a transparent canvas. Printify prints it over the product's own design. In
# the fields' order, as the storefront shows them: a background color fills its box, a photo fills
# it as the buyer framed it, a picture fits it, a star map is the sky's disc in it, and text fits it
# in its font and color.
class Personalization::PrintFile
  FONTS = Rails.root.join("lib/personalization/fonts")

  Error = Class.new(StandardError)

  # placeholders: a gray box for a photo the buyer hasn't added (a sample print file).
  def initialize(product, properties, side: "front", placeholders: false)
    @product, @properties, @side, @placeholders = product, properties.to_h, side, placeholders
  end

  attr_reader :side

  # A print file per side with something on it ([] when nothing is).
  def self.sides(product, properties)
    Product::PRINT_POSITIONS.map { |side| new(product, properties, side:) }.select { |file| file.layers.any? }
  end

  # Whether the shop prints these by itself: something to print, and a print area on each side of it.
  def self.printable?(product, properties)
    files = sides(product, properties)
    files.any? && files.all?(&:printable?)
  end

  # What a buyer could add, for the owner to see where it prints: each field's label as its text,
  # the first picture and color, a gray box for a photo.
  def self.sample(product, side: "front")
    properties = product.buyer_inputs.each_with_object({}) do |field, sample|
      sample[field["key"]] = case field["kind"]
      when "photo" then "sample"
      when "choice" then field["options"].to_a.first.to_s
      when "color" then field.dig("preview", "colors").to_a.first
      else field["label"]
      end
    end
    new(product, properties.compact_blank, side:, placeholders: true)
  end

  # Whether there's anything to print on this side and somewhere to put it.
  def printable?
    area.present? && layers.any?
  end

  # The PNG, width × height pixels (Printify's print area).
  def render(width:, height:)
    canvas = Vips::Image.black(width, height, bands: 4).copy(interpretation: :srgb)
    layers.each do |layer|
      left, top, box_width, box_height = place(layer, width, height)
      next if box_width < 1 || box_height < 1

      piece = draw(layer, box_width, box_height) or next
      canvas = canvas.composite2(piece, :over, x: left, y: top)
    end
    canvas.write_to_buffer(".png")
  end

  def layers
    @layers ||= BuyerInputs.layers(@product.buyer_inputs.select { |field| BuyerInputs.side(field) == @side }, @properties)
  end

  # The side's print area on the product's photo: { x, y, w, h, pixels }, or nil.
  def area
    @product.print_areas[@side]
  end

  private
    # The layer's box on the print area, in pixels: [left, top, width, height].
    def place(layer, width, height)
      left = (layer["x"] - area["x"]) / area["w"] * width
      top = (layer["y"] - area["y"]) / area["h"] * height
      [ left.round, top.round, (layer["w"] / area["w"] * width).round, (layer["h"] / area["h"] * height).round ]
    end

    def draw(layer, width, height)
      case layer["kind"]
      when "color" then fill(layer["color"], width, height)
      when "photo"
        upload = BuyerUpload.find_by(token: layer["upload"])
        upload ? look(photo(upload.photo.download, layer["crop"], width, height), layer["filter"]) : (fill("#d1d5db", width, height) if @placeholders)
      when "choice" then (art = @product.artwork.attachments.find_by(id: layer["artwork"])) && picture(art.download, width, height)
      when "starmap" then (sky = Personalization::Sky.for(layer["when"], layer["place"])) && star_map(sky, layer, width, height)
      else text(layer, width, height)
      end
    end

    # The night sky, as large a disc as fits, centered. rsvg-convert draws its SVG (libvips's SVG
    # loader is blocked, for buyers' files; Debian's ImageMagick hands SVG to rsvg-convert anyway).
    def star_map(sky, layer, width, height)
      size = [ width, height ].min
      png, error, status = Open3.capture3("rsvg-convert", stdin_data: sky.svg(size, sky: layer["sky"], ink: layer["ink"], lines: layer["lines"]), binmode: true)
      raise Error, "Couldn't draw the star map: #{error.truncate(200)}" unless status.success?

      disc = Vips::Image.new_from_buffer(png, "")
      rgba(disc).embed((width - disc.width) / 2, (height - disc.height) / 2, width, height, extend: :background, background: [ 0, 0, 0, 0 ])
    end

    def fill(hex, width, height)
      red, green, blue = hex.delete_prefix("#").scan(/../).map { |part| part.to_i(16) }
      Vips::Image.black(width, height).new_from_image([ red, green, blue, 255 ]).copy(interpretation: :srgb)
    end

    # Fills the box, zoomed and moved as the buyer framed it (BuyerInputs.crop): the point (x, y) of
    # the photo sits at the same point of the box, as in the storefront.
    def photo(data, crop, width, height)
      zoom, x, y = crop
      image = rgba(Vips::Image.new_from_buffer(data, "").autorot)
      scale = [ width.to_f / image.width, height.to_f / image.height ].max * zoom
      image = image.resize(scale)
      left = (x * image.width - x * width).round.clamp(0, [ image.width - width, 0 ].max)
      top = (y * image.height - y * height).round.clamp(0, [ image.height - height, 0 ].max)
      image.crop(left, top, [ width, image.width ].min, [ height, image.height ].min)
    end

    # Fits the box, centered.
    def picture(data, width, height)
      image = rgba(Vips::Image.new_from_buffer(data, ""))
      image = image.resize([ width.to_f / image.width, height.to_f / image.height ].min)
      image.embed((width - image.width) / 2, (height - image.height) / 2, width, height, extend: :background, background: [ 0, 0, 0, 0 ])
    end

    # The line at the largest size that fits the box, in its font, color and alignment (ImageMagick
    # draws it with the font's own file; libvips's text can't use one on every system): a monogram's
    # outer letters smaller than its middle one, bent along an arc when it curves.
    def text(layer, width, height)
      words = layer["uppercase"] || layer["style"] == "monogram" ? layer["text"].upcase : layer["text"]
      parts = if layer["style"] == "monogram"
        words.chars.first(3).each_with_index.map { |letter, index| [ letter, words.length == 3 && index != 1 ? MONOGRAM_SIDE : 1 ] }
      else
        [ [ words, 1 ] ]
      end
      line = side_by_side(parts.map { |part, share| label(part, layer, (height * share).round.clamp(8, 2000)) })
      line = arc(line, layer["curve"].to_i) unless layer["curve"].to_i.zero?
      line = line.resize([ width.to_f / line.width, height.to_f / line.height ].min)
      left = { "left" => 0, "right" => width - line.width }.fetch(layer["align"], (width - line.width) / 2)
      line.embed(left, (height - line.height) / 2, width, height, extend: :background, background: [ 0, 0, 0, 0 ])
    end

    MONOGRAM_SIDE = 0.72

    def label(words, layer, size)
      font = FONTS.join("#{layer["font"].to_s.parameterize}.ttf")
      raise Error, "No print font for #{layer["font"]}" unless font.exist?

      rgba(Vips::Image.new_from_buffer(magick("-background", "none", "-fill", layer["color"], "-font", font.to_s,
        "-pointsize", size.to_s, "label:#{self.class.escape(words)}", "png32:-"), ""))
    end

    # Parts in a row, their middles level.
    def side_by_side(images)
      return images.first if images.one?

      height = images.map(&:height).max
      images.inject(nil) do |row, image|
        image = image.embed(0, (height - image.height) / 2, image.width, height, extend: :background, background: [ 0, 0, 0, 0 ])
        row ? row.join(image, :horizontal) : image
      end
    end

    # Bent along an arc of that many degrees: up for an arch, down (negative) for a smile.
    def arc(image, degrees)
      flip = degrees.negative? ? %w[ -rotate 180 ] : []
      png = magick("png32:-", "-virtual-pixel", "transparent", *flip, "-distort", "Arc", degrees.abs.to_s, *flip, "+repage", "png32:-",
        stdin: image.write_to_buffer(".png"))
      Vips::Image.new_from_buffer(png, "")
    end

    def magick(*arguments, stdin: nil)
      out, error, status = Open3.capture3(self.class.magick, *arguments, stdin_data: stdin, binmode: true)
      raise Error, "Couldn't draw the text: #{error.truncate(200)}" unless status.success?

      out
    end

    # How the buyer chose their photo to look (CSS's grayscale(1) and sepia(1), so the print matches).
    def look(image, filter)
      return image unless %w[ bw sepia ].include?(filter)

      color, alpha = image.extract_band(0, n: 3), image.extract_band(3)
      color = if filter == "bw"
        gray = color.recomb([ [ 0.2126, 0.7152, 0.0722 ] ])
        gray.bandjoin([ gray, gray ])
      else
        color.recomb([ [ 0.393, 0.769, 0.189 ], [ 0.349, 0.686, 0.168 ], [ 0.272, 0.534, 0.131 ] ])
      end
      color.cast(:uchar).bandjoin(alpha).copy(interpretation: :srgb)
    end

    def rgba(image)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb
      image = image.bandjoin(255) if image.bands == 3
      image = image.bandjoin([ image, image ]).bandjoin(255) if image.bands == 1
      image.bands == 2 ? image.extract_band(0).bandjoin([ image.extract_band(0), image.extract_band(0), image.extract_band(1) ]) : image
    end

    class << self
      # ImageMagick 7 is "magick", 6 (Debian's) is "convert".
      def magick
        @magick ||= ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "magick")) } ? "magick" : "convert"
      end

      # A label is text, not a command: "@file" would read a file, "%w" and "\n" are escapes.
      def escape(words)
        words.gsub("\\") { "\\\\" }.gsub("%", "%%").sub(/\A@/) { "\\@" }
      end
    end
end
