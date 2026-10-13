# Makes a shop product from one of the owner's Printify products, or brings an imported one up
# to date: its options (Color, Size), a variant for each one Printify offers with Printify's price
# and cost, and its mockups, each tied to the color it shows. Combinations Printify doesn't make
# stay off sale. On an update the owner's title, description and prices are kept; costs, what's
# offered and new variants come from Printify.
class Printify::Import
  MAX_PHOTOS = 12
  OPTION_NAMES = { "color" => "Color", "size" => "Size" }.freeze

  def initialize(store = Store.current)
    @store = store
    @gateway = store.printify or raise PrintifyGateway::Error, "Printify isn't connected"
  end

  # The owner's Printify products, page by page, with whether each is in the shop already.
  def list(page: 1)
    result = @gateway.products(@store.printify_shop_id, page:)
    imported = Product.where(printify_product_id: result["data"].map { |item| item["id"] }).index_by(&:printify_product_id)
    items = result["data"].map do |item|
      { id: item["id"], title: item["title"], image: item["images"]&.find { |image| image["is_default"] }&.dig("src") || item.dig("images", 0, "src"),
        product: imported[item["id"]] }
    end
    [ items, result["last_page"].to_i ]
  end

  def call(printify_product_id)
    data = @gateway.product(@store.printify_shop_id, printify_product_id)
    offered = data["variants"].select { |variant| variant["is_enabled"] && variant["is_available"] != false }
    raise PrintifyGateway::Error, "#{data["title"]} has no variants on sale in Printify" if offered.empty?

    options = options_from(data["options"], offered)
    product = Product.find_or_initialize_by(printify_product_id: data["id"].to_s)
    new_product = product.new_record?

    Product.transaction do
      if new_product
        product.assign_attributes(title: data["title"], description: plain_text(data["description"]), status: "active",
          base_price_cents: offered.map { |variant| variant["price"] }.min)
      end
      options.each_with_index do |(name, values), index|
        product.public_send("option#{index + 1}_name=", name)
        product.public_send("option#{index + 1}_values=", values.map { |value| value[:title] })
      end
      product.save!
      update_variants(product, options, offered, new_product)
    end

    attach_photos(product, data["images"], options, offered) if product.images.none?
    product
  end

  private
    # [["Color", [{ id: 521, title: "Black" }, …]], ["Size", …]]: the options and the values
    # some offered variant uses, in Printify's order, at most three.
    def options_from(options, offered)
      used = offered.flat_map { |variant| variant["options"] }.to_set
      options.first(Product::OPTION_SLOTS.size).filter_map do |option|
        values = option["values"].select { |value| used.include?(value["id"]) }.map { |value| { id: value["id"], title: value["title"].to_s.squish } }
        [ OPTION_NAMES.fetch(option["type"].to_s, option["name"].to_s.squish.singularize.titleize), values ] if values.any?
      end
    end

    def update_variants(product, options, offered, new_product)
      by_titles = offered.index_by { |variant| titles_for(variant, options) }
      product.variants.reload.each do |variant|
        source = by_titles[variant.option_values]
        if source
          variant.price_cents = source["price"] if new_product || variant.printify_variant_id.nil?
          variant.update!(printify_variant_id: source["id"], cost_cents: source["cost"], sku: variant.sku || source["sku"], available: true)
        else
          variant.update!(printify_variant_id: nil, available: false)
        end
      end
    end

    def titles_for(variant, options)
      options.map { |_name, values| values.find { |value| variant["options"].include?(value[:id]) }&.dig(:title) }
    end

    # The default mockup first, then one for each color (named after the color, so the product
    # page shows it when the color is picked), then the default color's other views (the back).
    def attach_photos(product, images, options, offered)
      color_index = options.index { |name, _| name == "Color" }
      sorted = images.sort_by { |image| [ image["is_default"] ? 0 : 1, image["position"].to_s == "front" ? 0 : 1 ] }
      picked = []
      picked << [ sorted.first, nil ] if sorted.any?
      if color_index
        options[color_index].last.each do |color|
          ids = offered.select { |variant| variant["options"].include?(color[:id]) }.map { |variant| variant["id"] }
          image = sorted.find { |candidate| (candidate["variant_ids"] & ids).any? }
          picked << [ image, color[:title] ] if image
        end
      end
      if sorted.any?
        default_ids = sorted.first["variant_ids"]
        sorted.drop(1).each { |image| picked << [ image, nil ] if (image["variant_ids"] & default_ids).any? }
      end

      # One of each photo, keeping the color it shows when it's picked twice (the cover is a color's too).
      picked = picked.each_with_object({}) { |(image, color), by_src| by_src[image["src"]] = [ image, by_src.dig(image["src"], 1) || color ] }.values.first(MAX_PHOTOS)
      picked.each_with_index do |(image, color), index|
        product.images.attach(io: @gateway.download(image["src"]), filename: "#{product.slug}-#{color ? color.parameterize : "main-#{index}"}.jpg", content_type: "image/jpeg")
      end
      product.save!
      colors = picked.map(&:last)
      product.update!(option_images: product.images.attachments.order(:id).zip(colors).each_with_object({}) { |(photo, color), map| map[color] = photo.id if color })
    end

    def plain_text(html)
      text = html.to_s.gsub(%r{<br\s*/?>|</li>}i, "\n").gsub(%r{</p>}i, "\n\n")
      ActionController::Base.helpers.strip_tags(text).gsub(/\n{3,}/, "\n\n").strip
    end
end
