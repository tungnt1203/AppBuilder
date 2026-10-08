module AgentApi
  # The ids agents see: "product-<slug>" for a product (a family when it has options) and
  # "variant-<id>" for one of its variants.
  module Ids
    module_function

    def product(product) = "product-#{product.slug}"
    def variant(variant) = "variant-#{variant.id}"

    # A product or variant from an id, or nil.
    def find(id)
      case id.to_s
      when /\Avariant-(\d+)\z/ then Variant.includes(:product).find_by(id: $1)
      when /\Aproduct-([a-z0-9-]+)\z/ then Product.includes(:variants).find_by(slug: $1)
      end
    end

    # The variant an id stands for when it's bought: a variant, or a product without options.
    def buyable_variant(id)
      record = find(id)
      record.is_a?(Product) && !record.has_options? ? record.variants.first : (record if record.is_a?(Variant))
    end

    def money(cents) = (cents.to_i / 100.0).round(2)
  end
end
