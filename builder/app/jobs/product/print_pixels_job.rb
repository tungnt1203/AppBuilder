# Asks Printify how many pixels it prints a product's print area at (its blank's, from the print
# provider) and keeps it with the area (print_area["pixels"]), so buyers hear when their photo is
# too small to print sharp (Product#print_pixels). Without a product (config/recurring.yml, daily)
# it does so for every shop's products still without it: areas drawn before this, or before
# Printify answered.
class Product::PrintPixelsJob < ApplicationJob
  def perform(product = nil)
    return find(product) if product

    Shop.each_in_turn do
      next unless Store.current.printify_connected?

      Product.where.not(printify_product_id: nil).where("print_area ? 'x' AND NOT print_area ? 'pixels'").find_each { |each| find(each) }
    end
  end

  private
    def find(product)
      store = Store.current
      return unless product.print_area.present? && product.printify_product_id && store.printify_connected?

      printify = store.printify.product(store.printify_shop_id, product.printify_product_id)
      variants = store.printify.catalog_variants(printify["blueprint_id"], printify["print_provider_id"])["variants"].to_a
      area = variants.flat_map { |variant| variant["placeholders"].to_a }.find { |placeholder| placeholder["position"] == product.print_area["position"] } or return
      product.update_columns(print_area: product.print_area.merge("pixels" => [ area["width"].to_i, area["height"].to_i ]))
    rescue PrintifyGateway::Error
      nil # asked again tomorrow
    end
end
