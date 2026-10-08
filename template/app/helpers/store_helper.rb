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

  # A policy's starting text for this shop (app/views/admin/policies/templates), for the owner to
  # read and adjust before saving.
  def policy_template(id, store)
    render(partial: "admin/policies/templates/#{id}", formats: :text, locals: {
      shop: Rails.configuration.x.app_name, currency: store.currency,
      contact: store.contact_email.presence || "[your email]", shipping: shipping_summary(store)
    }).strip
  end

  def shipping_summary(store)
    first, additional, free = store.shipping_first_item_cents, store.shipping_additional_item_cents, store.free_shipping_threshold_cents
    return t("policies.shipping_summary.free") if first.zero? && additional.zero?

    [ t("policies.shipping_summary.rates", first: money(first, store.currency), additional: money(additional, store.currency)),
      (t("policies.shipping_summary.free_from", amount: money(free, store.currency)) if free) ].compact.join(" ")
  end

  # Policy text as written in /admin: paragraphs split by blank lines, "## " starts a heading,
  # lines starting with "- " make a list.
  def policy_text(text)
    blocks = text.to_s.strip.split(/\r?\n\s*\r?\n/).map do |block|
      lines = block.lines.map(&:strip)
      if lines.one? && lines.first.start_with?("## ")
        tag.h2(lines.first.delete_prefix("## "), class: "mt-10 font-display text-xl font-semibold text-ink")
      elsif lines.all? { |line| line.start_with?("- ") }
        tag.ul(safe_join(lines.map { |line| tag.li(line.delete_prefix("- ")) }), class: "mt-4 list-disc space-y-1 pl-5")
      else
        tag.p(safe_join(lines, tag.br), class: "mt-4")
      end
    end
    safe_join(blocks)
  end

  # "10% off · from $30 · until Oct 31" for the discounts list.
  def discount_summary(discount)
    [ case discount.kind
      when "percentage" then t("admin.discounts.summary.percentage", percent: discount.percent_off)
      when "fixed_amount" then t("admin.discounts.summary.fixed_amount", amount: money(discount.amount_off_cents))
      else t("admin.discounts.summary.free_shipping")
      end,
      (t("admin.discounts.summary.minimum", amount: money(discount.minimum_subtotal_cents)) if discount.minimum_subtotal_cents),
      (t("admin.discounts.summary.until", date: l(discount.ends_at, format: :short)) if discount.ends_at),
      (t("admin.discounts.summary.limit", count: discount.usage_limit) if discount.usage_limit) ].compact.join(" · ")
  end
end
