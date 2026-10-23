# A few print-on-demand products with mockups, colors, sizes, a size guide and Printify-like
# costs, so a new shop's preview has products to show and try buying before the owner's are in.
# A builder project's shop gets them when it opens (Project#ensure_shop!); the owner adds them
# again or removes them from /admin (Products). They're marked `demo` and removed together. Only
# the builder's preview shows them, and only until the shop has products of its own
# (StorefrontApi::V1::BaseController#visible_products): a published storefront never does.
class DemoCatalog
  IMAGES = Rails.root.join("lib/platform/demo")
  TEE_SIZES = <<~GUIDE.strip
    Size | Chest (in) | Length (in)
    S | 18 | 28
    M | 20 | 29
    L | 22 | 30
    XL | 24 | 31
    2XL | 26 | 32

    Measured flat across the chest. Unisex fit: size down for a closer fit.
  GUIDE

  def self.present?
    Product.where(demo: true).exists?
  end

  # Adds the demo products (once). Returns how many there are.
  def self.add!
    return Product.where(demo: true).count if present?

    Product.transaction do
      tee = product("Good Things Tee", price: "24", cost: "11.50", photos: %w[ classic-tee-black classic-tee-white classic-tee-navy ],
        description: "Heavyweight 100% cotton tee with a quiet reminder on the front. Printed to order, just for you.",
        option1_name: "Color", option1_values_text: "Black, White, Navy", option2_name: "Size", option2_values_text: "S, M, L, XL, 2XL", size_guide: TEE_SIZES)
      tee.variants.where(option2: "2XL").find_each { |variant| variant.update!(price: "27", cost: "13.50") }

      sunset = product("Stay Golden Tee", price: "26", cost: "11.50", photos: %w[ sunset-tee sunset-tee-detail ],
        description: "A retro sunset on soft forest-green cotton. Printed to order.",
        option1_name: "Size", option1_values_text: "S, M, L, XL", size_guide: TEE_SIZES)
      sunset.variants.each { |variant| variant.update!(compare_at_price: "32") }

      hoodie = product("Weekend Mode Hoodie", price: "48", cost: "24", photos: %w[ weekend-hoodie weekend-hoodie-black ],
        description: "Brushed fleece hoodie for slow Saturdays. Printed to order.",
        option1_name: "Color", option1_values_text: "Sand, Black", option2_name: "Size", option2_values_text: "S, M, L, XL")
      mug = product("But First, Coffee Mug", price: "16", cost: "6", photos: %w[ morning-mug ],
        description: "Glossy ceramic mug, dishwasher and microwave safe.", option1_name: "Size", option1_values_text: "11 oz, 15 oz")
      mug.variants.find_by(option1: "15 oz")&.update!(price: "19", cost: "7.50")
      poster = product("Wander Poster", price: "22", cost: "9", photos: %w[ wander-poster ],
        description: "Museum-quality matte paper. Frame not included.", option1_name: "Size", option1_values_text: "12 × 16 in, 18 × 24 in")
      poster.variants.find_by(option1: "18 × 24 in")&.update!(price: "29", cost: "12")
      tote = product("Plant Person Tote", price: "18", cost: "8", photos: %w[ plant-tote ], description: "Sturdy natural canvas tote, 15 × 16 in.")
      sweatshirt = product("Slow Mornings Sweatshirt", price: "38", cost: "18", photos: %w[ slow-mornings-sweatshirt ],
        description: "Soft crewneck sweatshirt in sage, for unhurried starts. Printed to order.",
        option1_name: "Size", option1_values_text: "S, M, L, XL", size_guide: TEE_SIZES)
      stickers = product("Good Vibes Sticker Pack", price: "9", cost: "3.50", photos: %w[ good-vibes-stickers ],
        description: "Three kiss-cut vinyl stickers, waterproof and laptop ready.")

      personalize(tee, mug, poster)

      # Four products each and three collections, so grids and tiles fill their rows.
      Collection.create!(title: "Apparel", demo: true).arrange_products([ tee.id, sunset.id, hoodie.id, sweatshirt.id ])
      Collection.create!(title: "Gifts", demo: true).arrange_products([ mug.id, tote.id, poster.id, stickers.id ])
      Collection.create!(title: "Cozy picks", demo: true).arrange_products([ hoodie.id, sweatshirt.id, mug.id, poster.id ])
    end
    Product.where(demo: true).count
  end

  # Removes the demo products and collections. Orders placed for them keep their lines (titles and
  # prices are copied into orders). Returns how many products were removed.
  def self.remove!
    products = Product.where(demo: true).to_a
    Product.transaction do
      Collection.where(demo: true).destroy_all
      products.each(&:destroy!)
    end
    products.size
  end

  # What makes personalized products the shop's kind: a name on the tee (on its dark photos, in the
  # buyer's pick of fonts and colors), the buyer's photo on the mug (in their pick of looks), and
  # names under the poster's art. Boxes are where the mockups have room.
  def self.personalize(tee, mug, poster)
    dark = tee.images.select { |photo| photo.filename.to_s.match?(/black|navy/) }.map(&:id)
    tee.update!(buyer_inputs: [ { "label" => "Name", "max_length" => "14",
      "preview" => { "x" => 0.3125, "y" => 0.6812, "w" => 0.3819, "h" => 0.0826, "images" => dark, "font" => "Montserrat", "color" => "#ffffff",
                     "fonts" => [ "Montserrat", "Pacifico", "Playfair Display" ], "colors" => "#ffffff, #f2c45a, #e86a45", "uppercase" => "1" } } ])
    mug.update!(buyer_inputs: [ { "label" => "Your photo", "kind" => "photo", "required" => "1",
      "preview" => { "x" => 0.2847, "y" => 0.3878, "w" => 0.3125, "h" => 0.3067, "filters" => %w[ original bw sepia ] } } ])
    poster.update!(buyer_inputs: [ { "label" => "Names", "max_length" => "24",
      "preview" => { "x" => 0.30, "y" => 0.735, "w" => 0.40, "h" => 0.05, "font" => "Dancing Script", "color" => "#2f4a3f" } } ])
  end
  private_class_method :personalize

  def self.product(title, price:, cost:, photos:, **attributes)
    product = Product.create!(title:, status: "active", base_price: price, demo: true, **attributes)
    product.variants.each { |variant| variant.update!(cost:) }
    photos.each { |name| product.images.attach(io: IMAGES.join("#{name}.jpg").open, filename: "#{name}.jpg", content_type: "image/jpeg") }
    product.save!
    product
  end
  private_class_method :product
end
