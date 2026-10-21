require "date"
require "time"

module StorefrontKit
  # A photo in three sizes: thumb (160×160), card (640×800), large (up to 1400×1400).
  class Image < Record
    def url(size = :card) = self[size.to_s]
  end

  class Variant < Record
    optional :title, :sku, :compare_at_price_cents, :stock, :image_id
    def on_sale? = !compare_at_price_cents.nil?

    # How much it saves, as a whole percentage: 20.
    def sale_percent
      ((compare_at_price_cents - price_cents) * 100.0 / compare_at_price_cents).round if on_sale?
    end

    def available? = self["available"] ? true : false
  end

  class ProductOption < Record
    def color? = name.to_s.match?(/\bcolou?r\b/i)
    def color_for(value) = self["colors"]&.dig(value.to_s)
  end

  class Rating < Record; end

  class Product < Record
    optional :description, :size_guide, :size_option
    one :image, Image
    many :images, Image
    many :variants, Variant
    many :options, ProductOption
    one :rating, Rating

    def to_param = slug
    def cover_image = image
    def available? = self["available"] ? true : false
    def made_to_order? = self["made_to_order"] ? true : false
    def min_price_cents = self["price"]&.dig("min_cents")
    def max_price_cents = self["price"]&.dig("max_cents")
    def compare_at_cents = self["price"]&.dig("compare_at_cents")
    def currency = self["price"]&.dig("currency")
    def on_sale? = !compare_at_cents.nil?
    def collections = Array(self["collections"]).map { |collection| Collection.new(collection) }
    def custom_fields = Array(self["custom_fields"])
    def buyer_inputs = Array(self["buyer_inputs"])

    # The variant with these option values (["Black", "M"]), nil when none matches.
    def variant_for(values)
      values = Array(values).map(&:to_s)
      variants.find { |variant| variant.options == values } if values.any?
    end

    def available_variants = variants.select(&:available?)

    # The photo that shows this variant (its color), else the product's first.
    def image_for(variant)
      images.find { |photo| photo.id == variant&.image_id } || image
    end

    def custom_field(key) = custom_fields.find { |field| field["key"] == key.to_s }&.dig("value")
  end

  class Collection < Record
    optional :description, :product_count
    def to_param = slug
  end

  # A page of a list: records, and where it is among the others.
  class ListPage
    include Enumerable

    attr_reader :records, :number, :per, :total, :pages

    def initialize(records, page:, per_page:, total:, pages: nil)
      @records, @number, @per, @total = records, page.to_i, per_page.to_i, total.to_i
      @pages = pages || [ (@total.to_f / [ @per, 1 ].max).ceil, 1 ].max
    end

    def each(&) = records.each(&)
    def empty? = records.empty?
    def previous = (number - 1 if number > 1)
    def next = (number + 1 if number < pages)
    def many? = pages > 1
  end

  class Review < Record
    optional :body
    def created_at = (Time.iso8601(self["created_at"]) if self["created_at"])
  end

  class Property < Record; end # what the buyer typed: key, label, value

  class CartItem < Record
    one :product, Product
    one :variant, Variant
    many :properties, Property
  end

  class Discount < Record
    def free_shipping? = kind == "free_shipping"
  end

  class Cart < Record
    optional :free_shipping_remaining_cents
    many :items, CartItem
    one :discount, Discount

    def to_param = token
    def empty? = items.empty?
  end

  # What a checkout comes to for the address so far, and what's wrong with it (problems).
  class Checkout < Record
    optional :discount_code
    many :items, CartItem

    attr_reader :problems

    def initialize(data = {}, problems: nil)
      super(data)
      @problems = problems || {}
    end

    def shipping_known? = self["shipping_known"] ? true : false
    def phone_required? = self["phone_required"] ? true : false
  end

  class OrderItem < Record
    optional :variant_title, :product_slug, :catalog_id
    one :image, Image
    many :properties, Property
  end

  class Address < Record
    optional :name, :address1, :address2, :city, :region, :postal_code, :country
    def lines = [ name, address1, address2.presence, [ city, region, postal_code ].compact_blank.join(" "), country ].compact_blank
  end

  class Payment < Record
    optional :instructions, :test_mode
    def card? = self["method"] == "stripe" || self["provider"] == "stripe"
    def required? = self["required"] ? true : false
  end

  class Order < Record
    optional :discount_code, :paid_at, :shipped_at, :delivered_at, :cancelled_at, :refunded_at
    many :items, OrderItem
    one :shipping_address, Address
    one :payment, Payment
    one :tracking, Record
    many :reviewable_products, Product

    STATUSES = %w[ pending paid in_production shipped delivered cancelled refunded ].freeze
    STATUSES.each { |status| define_method(:"#{status}?") { self["status"] == status } }

    def to_param = token
    def card? = payment&.card?
    def test? = self["test"] ? true : false
    def placed_at = Time.iso8601(self["placed_at"])
  end

  # A buyer's orders at the shop, found by their email (Api#order_lookup).
  class OrderLookup < Record
    many :orders, Order
  end

  class Country < Record
    def regions = self["regions"]
  end

  class Shipping < Record
    optional :free_over_cents, :ships_to, :delivery_days
    many :countries, Country

    # [first, last] days the buyer can expect it, when the shop says how long delivery takes.
    def delivery_dates
      dates = self["delivery_dates"] or return
      [ Date.iso8601(dates["first"]), Date.iso8601(dates["last"]) ]
    end
  end

  class Shop < Record
    optional :announcement, :payment_instructions
    one :shipping, Shipping
    one :pixels, Record
    one :contact, Record

    def preview? = self["preview"] ? true : false
    def tax_at_payment? = self["tax_at_payment"] ? true : false
    def theme_settings = self["theme_settings"] || {}
    def policies = Array(self["policies"])
    def policy?(id) = policies.any? { |policy| policy["id"] == id.to_s }
    def ad_tracking? = pixels.to_h.values.any? { |id| id.to_s != "" }
    def card_payments? = Array(payment_methods).include?("stripe")
  end

  class Page < Record
    def to_param = slug
    def blocks = Array(self["blocks"])
  end

  class Menu < Record
    def items = Array(self["items"])
  end

  class Policy < Record
    optional :body
  end
  class Form < Record; end
end
