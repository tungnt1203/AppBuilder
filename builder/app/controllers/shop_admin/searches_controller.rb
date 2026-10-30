# The admin's quick search (⌘K): orders by number, email or name, customers, products, and the
# admin's own screens, a few of each, for the palette to show as the owner types.
class ShopAdmin::SearchesController < ShopAdmin::BaseController
  def show
    @query = params[:q].to_s.strip.first(100)
    if @query.present?
      @orders = Order.real.search(@query).newest_first.limit(5)
      @customers = Buyer.all(query: @query).limit(4) unless @query.delete_prefix("#").match?(/\A\d+\z/)
      @products = Product.search(@query).ordered.with_attached_images.limit(5)
    end
    render layout: false
  end
end
