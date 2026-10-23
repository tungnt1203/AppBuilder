# A personalized item's line of a Printify order: the product's blank made for this order (Printify
# makes a product per line from its blueprint, print provider and print areas) with the product's
# own design in each print area and, over it on each side the buyer added something to, the item's
# print file of that side (Personalization::PrintFile, at that print area's size). The print files
# are kept on the item for staff to see.
class Personalization::PrintifyLine
  def initialize(item, gateway:, shop_id:)
    @item, @gateway, @shop_id = item, gateway, shop_id
  end

  def to_h
    product = @item.variant.product
    printify = @gateway.product(@shop_id, product.printify_product_id)
    variant_id = @item.variant.printify_variant_id.to_i
    areas = Array(printify["print_areas"]).find { |area| Array(area["variant_ids"]).map(&:to_i).include?(variant_id) }
    raise Personalization::PrintFile::Error, "Printify's #{product.title} has no print area for this variant" unless areas

    print_areas = Array(areas["placeholders"]).to_h { |placeholder| [ placeholder["position"], Array(placeholder["images"]).filter_map { |image| design(image) } ] }
    @item.print_files.purge # from an earlier try
    Personalization::PrintFile.sides(product, @item.properties).each do |file|
      print_areas[file.side] = print_areas.fetch(file.side, []) + [ print_file(file, printify, variant_id) ]
    end
    { blueprint_id: printify["blueprint_id"], print_provider_id: printify["print_provider_id"], variant_id:, quantity: @item.quantity,
      print_areas: print_areas.reject { |_position, images| images.empty? } }
  end

  private
    # One of the product's own images, where it sits. Text made in Printify's editor can't go with an
    # order made this way: the owner uploads it as an image instead. What Printify adds by itself
    # (the neck label's size and care text, "text/plain") isn't the owner's design and is left out.
    def design(image)
      return unless image["layerType"] == "text" || image["type"].to_s.start_with?("image/")

      if image["layerType"] == "text"
        raise Personalization::PrintFile::Error, "#{@item.variant.product.title}'s design in Printify has text made there (\"#{image["input_text"]}\"). " \
          "Printify takes only images with a personalized order: upload the design as an image (PNG) in Printify instead."
      end

      src = image["src"].presence || @gateway.upload(image["id"])["preview_url"]
      { src:, x: image["x"], y: image["y"], scale: image["scale"], angle: image["angle"] || 0 }
    end

    # The buyer's part of a side, the print area's size, over the whole of it.
    def print_file(file, printify, variant_id)
      position = file.side
      sizes = @gateway.catalog_variants(printify["blueprint_id"], printify["print_provider_id"])
      area = Array(sizes["variants"]).find { |variant| variant["id"].to_i == variant_id }.to_h["placeholders"].to_a.find { |placeholder| placeholder["position"] == position }
      raise Personalization::PrintFile::Error, "Printify has no #{position} print area for this variant" unless area

      png = file.render(width: area["width"].to_i, height: area["height"].to_i)
      name = "#{@item.order.number}-#{@item.id}-#{position}.png"
      @item.print_files.attach(io: StringIO.new(png), filename: name, content_type: "image/png")
      upload = @gateway.upload_image(name, png)
      { src: upload["preview_url"], x: 0.5, y: 0.5, scale: 1, angle: 0 }
    end
end
