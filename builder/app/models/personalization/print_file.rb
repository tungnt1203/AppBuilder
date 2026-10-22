require "open3"

# The print file of a personalized line: what the buyer added (BuyerInputs.layers), drawn where the
# owner placed it on the product's photo and moved onto Printify's print area (the product's
# print_area, drawn on that photo), at the print area's size, on a transparent canvas. Printify
# prints it over the product's own design. In the fields' order, as the storefront shows them: a
# background color fills its box, a photo fills it as the buyer framed it, a picture fits it, and
# text fits it in its font and color.
class Personalization::PrintFile
  FONTS = Rails.root.join("lib/personalization/fonts")

  Error = Class.new(StandardError)

  # placeholders: a gray box for a photo the buyer hasn't added (a sample print file).
  def initialize(product, properties, placeholders: false)
    @product, @properties, @placeholders = product, properties.to_h, placeholders
  end

  # What a buyer could add, for the owner to see where it prints: each field's label as its text,
  # the first picture and color, a gray box for a photo.
  def self.sample(product)
    properties = product.buyer_inputs.each_with_object({}) do |field, sample|
      sample[field["key"]] = case field["kind"]
      when "photo" then "sample"
      when "choice" then field["options"].to_a.first.to_s
      when "color" then field.dig("preview", "colors").to_a.first
      else field["label"]
      end
    end
    new(product, properties.compact_blank, placeholders: true)
  end

  # Whether there's anything to print and somewhere to put it.
  def printable?
    @product.print_area.present? && layers.any?
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
    @layers ||= BuyerInputs.layers(@product.buyer_inputs, @properties)
  end

  private
    # The layer's box on the print area, in pixels: [left, top, width, height].
    def place(layer, width, height)
      area = @product.print_area
      left = (layer["x"] - area["x"]) / area["w"] * width
      top = (layer["y"] - area["y"]) / area["h"] * height
      [ left.round, top.round, (layer["w"] / area["w"] * width).round, (layer["h"] / area["h"] * height).round ]
    end

    def draw(layer, width, height)
      case layer["kind"]
      when "color" then fill(layer["color"], width, height)
      when "photo"
        upload = BuyerUpload.find_by(token: layer["upload"])
        upload ? photo(upload.photo.download, layer["crop"], width, height) : (fill("#d1d5db", width, height) if @placeholders)
      when "choice" then (art = @product.artwork.attachments.find_by(id: layer["artwork"])) && picture(art.download, width, height)
      else text(layer, width, height)
      end
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
    # draws it with the font's own file; libvips's text can't use one on every system).
    def text(layer, width, height)
      words = layer["uppercase"] ? layer["text"].upcase : layer["text"]
      font = FONTS.join("#{layer["font"].to_s.parameterize}.ttf")
      raise Error, "No print font for #{layer["font"]}" unless font.exist?

      gravity = { "left" => "West", "right" => "East" }.fetch(layer["align"], "Center")
      png, error, status = Open3.capture3(self.class.magick, "-background", "none", "-fill", layer["color"], "-font", font.to_s,
        "-size", "#{width}x#{height}", "-gravity", gravity, "label:#{self.class.escape(words)}", "png32:-", binmode: true)
      raise Error, "Couldn't draw the text: #{error.truncate(200)}" unless status.success?

      rgba(Vips::Image.new_from_buffer(png, ""))
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
