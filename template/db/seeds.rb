# Sample catalog for the preview in development, so the shop's pages have something to show:
# print-on-demand products with mockup photos (db/seeds/images). Replace it with the owner's real
# products (seed them here, idempotently, when they give them), and their photos with the owner's
# or ones that fit the shop (bin/images).
if Rails.env.development? && Product.none?
  Store.current
  images = Rails.root.join("db/seeds/images")
  photos = ->(product, *names) do
    names.each { |name| product.images.attach(io: images.join("#{name}.jpg").open, filename: "#{name}.jpg", content_type: "image/jpeg") }
    product.save!
  end

  tee = Product.create!(title: "Good Things Tee", status: "active", base_price: "24",
    description: "Heavyweight cotton tee with a quiet reminder on the front. Printed to order and shipped in 3–5 days.",
    option1_name: "Color", option1_values_text: "Black, White, Navy", option2_name: "Size", option2_values_text: "S, M, L, XL, 2XL")
  tee.variants.where(option2: "2XL").find_each { |variant| variant.update!(price: "27") }
  photos.(tee, "classic-tee-black", "classic-tee-white", "classic-tee-navy")

  sunset = Product.create!(title: "Stay Golden Tee", status: "active", base_price: "26",
    description: "A retro sunset on soft forest-green cotton. Printed to order.",
    option1_name: "Size", option1_values_text: "S, M, L, XL")
  sunset.variants.first.update!(compare_at_price: "32")
  photos.(sunset, "sunset-tee", "sunset-tee-detail")

  hoodie = Product.create!(title: "Weekend Mode Hoodie", status: "active", base_price: "48",
    description: "Brushed fleece hoodie for slow Saturdays. Printed to order.",
    option1_name: "Color", option1_values_text: "Sand, Black", option2_name: "Size", option2_values_text: "S, M, L, XL")
  photos.(hoodie, "weekend-hoodie", "weekend-hoodie-black")

  mug = Product.create!(title: "But First, Coffee Mug", status: "active", base_price: "16",
    description: "Glossy ceramic mug, dishwasher and microwave safe.", option1_name: "Size", option1_values_text: "11 oz, 15 oz")
  mug.variants.find_by(option1: "15 oz")&.update!(price: "19")
  photos.(mug, "morning-mug")

  poster = Product.create!(title: "Wander Poster", status: "active", base_price: "22",
    description: "Museum-quality matte paper. Frame not included.", option1_name: "Size", option1_values_text: "12 × 16 in, 18 × 24 in")
  poster.variants.find_by(option1: "18 × 24 in")&.update!(price: "29")
  photos.(poster, "wander-poster")

  tote = Product.create!(title: "Plant Person Tote", status: "active", base_price: "18",
    description: "Sturdy natural canvas tote, 15 × 16 in.")
  photos.(tote, "plant-tote")

  Collection.create!(title: "Graphic tees").arrange_products([ tee.id, sunset.id, hoodie.id ])
  Collection.create!(title: "Gifts").arrange_products([ mug.id, tote.id, poster.id, tee.id ])
  Collection.create!(title: "For the home").arrange_products([ mug.id, poster.id ])
end
