# Pieces of the shop shared by the site and /admin.
module StoreHelper
  # A product's photo in one of its sizes (:thumb, :card, :large), or a placeholder when it has none.
  def product_image(product, size: :card, image: product.cover_image, **options)
    options[:class] = class_names("bg-surface-muted object-cover", options[:class])
    if image&.representable?
      image_tag image.variant(size), alt: options.delete(:alt) || product.title, loading: "lazy", **options
    else
      tag.div(icon("shirt", size: 32, stroke: 1.5), class: class_names(options[:class], "grid place-items-center text-muted"), role: "img", aria: { label: product.title })
    end
  end

  ORDER_STATUS_TONES = {
    "pending" => :yellow, "paid" => :brand, "in_production" => :brand, "shipped" => :green,
    "delivered" => :green, "cancelled" => :gray, "refunded" => :red
  }.freeze

  def order_status_badge(order)
    badge t(order.status, scope: "orders.statuses"), tone: ORDER_STATUS_TONES.fetch(order.status, :gray)
  end

  PRODUCT_STATUS_TONES = { "active" => :green, "draft" => :yellow, "archived" => :gray }.freeze

  def product_status_badge(product)
    badge t(product.status, scope: "products.statuses"), tone: PRODUCT_STATUS_TONES.fetch(product.status, :gray)
  end

  # The variants of a product for the variant picker: what each costs and whether it can be bought.
  def variants_json(product)
    product.variants.map do |variant|
      { id: variant.id, options: variant.option_values, available: variant.buyable?,
        price: money(variant.price_cents), compare_at_price: (money(variant.compare_at_price_cents) if variant.on_sale?) }
    end.to_json
  end
end
