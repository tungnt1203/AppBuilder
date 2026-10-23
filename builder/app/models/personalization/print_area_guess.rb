# Where Printify's print area sits on a product's mockup photo, worked out instead of drawn: Printify
# says where the product's design sits in the print area (its first image: center, width as a share
# of the area, its pixels) and how big the area is; the design's ink is found on the photo (what
# differs from the shirt's color around the chest); the two give the area's box on the photo, as
# Product#print_area keeps it. Nil when the design can't be told apart on the photo (a lifestyle
# shot, a patterned blank, a design without a clear edge): the owner draws the area then.
class Personalization::PrintAreaGuess
  SEARCH = { x: 0.2..0.8, y: 0.12..0.85 }.freeze # where a front's design is on Printify's mockups
  SIZE = 300                                     # the photo is read at this width
  INK = 48                                       # how far from the shirt's color counts as ink (0–441)

  def initialize(product, gateway:, shop_id:)
    @product, @gateway, @shop_id = product, gateway, shop_id
  end

  # { "x", "y", "w", "h", "position", "pixels" } or nil.
  def call(position: "front")
    printify = @gateway.product(@shop_id, @product.printify_product_id)
    placeholder = Array(printify["print_areas"]).flat_map { |area| Array(area["placeholders"]) }.find { |candidate| candidate["position"] == position }
    image = Array(placeholder&.dig("images")).find { |candidate| candidate["type"].to_s.start_with?("image/") && candidate["src"].present? } or return
    variant_id = Array(printify["print_areas"]).find { |area| area["placeholders"].to_a.include?(placeholder) }.to_h["variant_ids"].to_a.first
    area = @gateway.catalog_variants(printify["blueprint_id"], printify["print_provider_id"])["variants"].to_a
      .find { |variant| variant["id"] == variant_id }.to_h["placeholders"].to_a.find { |candidate| candidate["position"] == position } or return
    design = Vips::Image.new_from_buffer(@gateway.download(image["src"]).read, "")
    photo = @product.images.attachments.first or return
    box = place(design, image, area, Vips::Image.new_from_buffer(photo.download, "")) or return
    box.merge("position" => position, "pixels" => [ area["width"].to_i, area["height"].to_i ])
  rescue PrintifyGateway::Error, Vips::Error
    nil
  end

  # The area's box on the photo, from the design's ink found there.
  def place(design, image, area, photo)
    ink = ink_box(design) or return
    seen = photo_box(photo) or return

    # The design in the print area, in shares of its width and height (Printify: center x, y; scale = width).
    width = image["scale"].to_f
    height = width * area["width"].to_f / area["height"] * design.height / design.width
    left, top = image["x"].to_f - width / 2, image["y"].to_f - height / 2
    # Its ink, in shares of the print area.
    ink_left = left + width * ink[0]
    ink_top = top + height * ink[1]
    ink_width = width * ink[2]
    ink_height = height * ink[3]
    return unless ink_width.positive? && ink_height.positive?

    # The ink's shape on the photo should be the design's: otherwise it found something else.
    found = seen[2] / seen[3]
    expected = (ink_width * area["width"].to_f) / (ink_height * area["height"].to_f)
    return unless (found / expected).between?(0.75, 1.33)

    area_width = seen[2] / ink_width
    area_height = area_width * area["height"].to_f / area["width"] * photo.width / photo.height
    box = { "x" => seen[0] - ink_left * area_width, "y" => seen[1] - ink_top * area_height, "w" => area_width, "h" => area_height }
    box.transform_values { |value| value.round(4) } if box.values.all? { |value| value.between?(-0.01, 1.01) } && box["x"] + box["w"] <= 1.01 && box["y"] + box["h"] <= 1.01
  end

  private
    # The design's ink inside its image: [left, top, width, height] as shares of it.
    def ink_box(design)
      alpha = design.bands == 4 || design.bands == 2 ? design.extract_band(design.bands - 1) : design.colourspace(:b_w).invert
      left, top, width, height = alpha.find_trim(threshold: 16, background: [ 0 ])
      return unless width.positive? && height.positive?

      [ left.to_f / design.width, top.to_f / design.height, width.to_f / design.width, height.to_f / design.height ]
    end

    # The design's ink on the photo: [left, top, width, height] as shares of it, around the chest.
    def photo_box(photo)
      small = photo.thumbnail_image(SIZE, height: SIZE * 4, size: :down)
      small = small.colourspace(:srgb)
      small = small.extract_band(0, n: 3) if small.bands > 3
      x0, x1 = (SEARCH[:x].begin * small.width).round, (SEARCH[:x].end * small.width).round
      y0, y1 = (SEARCH[:y].begin * small.height).round, (SEARCH[:y].end * small.height).round
      region = small.crop(x0, y0, x1 - x0, y1 - y0)
      shirt = shirt_color(region)
      ink = (((region - shirt) ** 2).bandmean.linear(3, 0) ** 0.5 > INK).to_a.map { |row| row.map { |pixel| pixel.first.positive? } }
      found = design_on(ink) or return
      left, top, right, bottom = found
      [ (x0 + left).to_f / small.width, (y0 + top).to_f / small.height, (right - left + 1).to_f / small.width, (bottom - top + 1).to_f / small.height ]
    end

    # The box of the design among what differs from the shirt: its marks grow a little so a word's
    # letters join, then thin or sparse ones (the collar's seam, a sleeve's edge, a fold) are left
    # out. [left, top, right, bottom] in pixels, or nil.
    def design_on(ink)
      height, width = ink.size, ink.first.size
      grown = Array.new(height) { |y| Array.new(width) { |x| (([ y - 2, 0 ].max)..([ y + 2, height - 1 ].min)).any? { |row| ink[row][([ x - 2, 0 ].max)..([ x + 2, width - 1 ].min)].any? } } }
      seen = Array.new(height) { Array.new(width, false) }
      marks = []
      height.times do |y|
        width.times do |x|
          next unless grown[y][x] && !seen[y][x]

          stack, cells = [ [ y, x ] ], []
          seen[y][x] = true
          while (cell = stack.pop)
            cells << cell
            row, column = cell
            [ [ row - 1, column ], [ row + 1, column ], [ row, column - 1 ], [ row, column + 1 ] ].each do |next_row, next_column|
              next unless next_row.between?(0, height - 1) && next_column.between?(0, width - 1) && grown[next_row][next_column] && !seen[next_row][next_column]

              seen[next_row][next_column] = true
              stack << [ next_row, next_column ]
            end
          end
          rows, columns = cells.map(&:first), cells.map(&:last)
          box = [ columns.min, rows.min, columns.max, rows.max ]
          area = (box[2] - box[0] + 1) * (box[3] - box[1] + 1)
          marks << box if [ box[2] - box[0], box[3] - box[1] ].min >= 7 && cells.size >= area * 0.6
        end
      end
      return if marks.empty?

      [ marks.map { |box| box[0] }.min + 2, marks.map { |box| box[1] }.min + 2, marks.map { |box| box[2] }.max - 2, marks.map { |box| box[3] }.max - 2 ]
    end

    # The most common color around the chest: the shirt's.
    def shirt_color(region)
      counts = Hash.new(0)
      region.to_a.each { |row| row.each { |pixel| counts[pixel.map { |value| (value / 16).floor }] += 1 } }
      counts.max_by(&:last).first.map { |value| value * 16 + 8 }
    end
end
