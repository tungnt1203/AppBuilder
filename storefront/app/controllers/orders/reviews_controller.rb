# Buyers review what they bought, from the link in their order's review email (or the order
# page) once it's on its way: stars and a few words for each product, under the name they choose.
class Orders::ReviewsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to order_path(params[:order_id]), alert: t("checkouts.rate_limited") }

  before_action :set_order
  helper_method :review_fields

  def new
    @author_name = default_author_name
  end

  def create
    @author_name = params[:author_name].to_s
    reviews = @products.map { |product| review_fields(product).merge(product_slug: product.slug) }.select { |review| review[:rating].present? }
    return pick_stars if reviews.empty?

    saved = storefront.review_order(@order.token, reviews:, author_name: @author_name.presence)
    redirect_to order_path(@order), notice: t(".thanks", count: saved.size)
  rescue StorefrontKit::Invalid => error
    flash.now[:alert] = error.fields.values.first || error.message
    render :new, status: :unprocessable_entity
  end

  private
    # What the buyer wrote for a product: { rating:, body: }, empty when nothing (or something odd) came.
    def review_fields(product)
      reviews = params[:reviews]
      fields = reviews.is_a?(ActionController::Parameters) ? reviews[product.slug] : nil
      fields.is_a?(ActionController::Parameters) ? fields.permit(:rating, :body).to_h.symbolize_keys : {}
    end

    def pick_stars
      flash.now[:alert] = t(".pick_stars")
      render :new, status: :unprocessable_entity
    end

    # "Robin B.": the first name and the last name's initial.
    def default_author_name
      first, *rest = @order.shipping_address&.name.to_s.split
      [ first, ("#{rest.last.first}." if rest.any?) ].compact.join(" ")
    end

    def set_order
      @order = storefront.order(params[:order_id])
      @products = @order.reviewable_products.map { |product| (storefront.product(product.slug) rescue product) }
      redirect_to order_path(@order), notice: t("orders.reviews.nothing_to_review") if @products.empty?
    end
end
