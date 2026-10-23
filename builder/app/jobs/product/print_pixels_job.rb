# Asks Printify how many pixels it prints each of a product's print areas at (its blank's, from the
# print provider) and keeps it with the area (print_areas[side]["pixels"]), so buyers hear when
# their photo is too small to print sharp (Product#print_pixels). Without a product
# (config/recurring.yml, daily) it does so for every shop's products still without it: areas drawn
# before this, or before Printify answered.
class Product::PrintPixelsJob < ApplicationJob
  def perform(product = nil)
    return find(product) if product

    Shop.each_in_turn do
      next unless Store.current.printify_connected?

      Product.where.not(printify_product_id: nil)
        .where("EXISTS (SELECT 1 FROM jsonb_each(products.print_areas) AS area WHERE NOT area.value ? 'pixels')").find_each { |each| find(each) }
    end
  end

  private
    def find(product)
      store = Store.current
      missing = product.print_areas.reject { |_side, area| area["pixels"] }
      return unless missing.any? && product.printify_product_id && store.printify_connected?

      printify = store.printify.product(store.printify_shop_id, product.printify_product_id)
      placeholders = store.printify.catalog_variants(printify["blueprint_id"], printify["print_provider_id"])["variants"].to_a.flat_map { |variant| variant["placeholders"].to_a }
      found = missing.filter_map do |side, area|
        size = placeholders.find { |placeholder| placeholder["position"] == side } or next
        [ side, area.merge("pixels" => [ size["width"].to_i, size["height"].to_i ]) ]
      end
      product.update_columns(print_areas: product.print_areas.merge(found.to_h)) if found.any?
    rescue PrintifyGateway::Error
      nil # asked again tomorrow
    end
end
