# What views use to show the shop: the shop and its theme settings, money, photos, menus, and
# the catalog straight from the API (products, collections) for a section of any page.
module StorefrontHelper
  # A value the owner set for one of the theme's settings (config/theme_settings.yml), or its default.
  def theme_setting(key) = current_shop.theme_settings[key.to_s]

  # "$24.00" in the shop's currency (or the one given).
  def money(cents, currency = current_shop.currency)
    return if cents.nil?

    format = StorefrontKit::Money.format_for(currency)
    number_to_currency(BigDecimal(cents) / 100, unit: format[:unit], precision: format[:precision],
      format: format.fetch(:format, "%u%n"), negative_format: "-#{format.fetch(:format, "%u%n")}")
  end

  # "$24.00", or "$24.00 – $28.00" when its variants cost differently.
  def price_range(product)
    low, high = product.min_price_cents, product.max_price_cents
    return unless low

    low == high ? money(low) : "#{money(low)} – #{money(high)}"
  end

  # The menu with this key (header, footer…) the owner made in the admin, nil when there's none.
  # (UiHelper's `menu` is the dropdown component.)
  def shop_menu(key)
    @storefront_menus ||= {}
    return @storefront_menus[key.to_s] if @storefront_menus.key?(key.to_s)

    @storefront_menus[key.to_s] = begin
      storefront.menu(key)
    rescue StorefrontKit::NotFound
      nil
    end
  end

  # products(collection: "cat-lovers", per_page: 4): a page of the catalog, for a section.
  def products(**query) = storefront.products(**query)
  def collections = (@storefront_collections ||= storefront.collections)

  # A photo of a product in one of its sizes (:thumb, :card, :large), or a placeholder without one.
  def product_image(product, size: :card, image: product.cover_image, **options)
    options[:class] = class_names("bg-surface-muted object-cover", options[:class])
    alt = options.delete(:alt) || product.title
    if image
      image_tag image.url(size), alt:, loading: "lazy", **options
    else
      tag.div(class: class_names(options[:class], "grid place-items-center text-muted"), role: "img", aria: { label: alt })
    end
  end

  # A menu item's link: a path on this storefront or a full address.
  def menu_url(item) = item["url"].to_s
end
