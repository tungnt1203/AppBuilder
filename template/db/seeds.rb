# Sample catalog for the preview in development, so the shop's pages have something to show.
# Replace it with the owner's real products (seed them here, idempotently, when they give them).
if Rails.env.development? && Product.none?
  Store.current

  tee = Product.create!(title: "Classic Logo Tee", status: "active", base_price: "24",
    description: "Heavyweight cotton, printed to order.",
    option1_name: "Color", option1_values_text: "Black, White, Navy", option2_name: "Size", option2_values_text: "S, M, L, XL")
  hoodie = Product.create!(title: "Everyday Hoodie", status: "active", base_price: "48",
    description: "Soft fleece hoodie, printed to order.", option1_name: "Size", option1_values_text: "S, M, L, XL")
  mug = Product.create!(title: "Morning Mug", status: "active", base_price: "16",
    description: "11 oz ceramic mug, dishwasher safe.", option1_name: "Size", option1_values_text: "11 oz, 15 oz")
  mug.variants.find_by(option1: "15 oz")&.update!(price: "19")
  poster = Product.create!(title: "Studio Poster", status: "active", base_price: "22", description: "Matte paper, 18 × 24 in.")

  Collection.create!(title: "Bestsellers").arrange_products([ tee.id, hoodie.id, mug.id ])
  Collection.create!(title: "For the home").arrange_products([ mug.id, poster.id ])
end
