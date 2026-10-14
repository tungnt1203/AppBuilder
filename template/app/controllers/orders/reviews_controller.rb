# Buyers review what they bought, from the link in their order's review email (or the order
# page) once it's on its way: stars and a few words for each product, under the name they choose.
class Orders::ReviewsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { redirect_to order_path(params[:order_id]), alert: t("checkouts.rate_limited") }

  before_action :set_order

  def new
    @author_name = ProductReview.default_author_name(@order.shipping_name)
  end

  def create
    @author_name = params[:author_name].to_s
    @reviews = @products.filter_map do |product|
      fields = params.dig(:reviews, product.id.to_s)
      @order.product_reviews.build(product:, rating: fields[:rating], body: fields[:body], author_name: @author_name) if fields && fields[:rating].present?
    end

    if @reviews.empty?
      flash.now[:alert] = t(".pick_stars")
      render :new, status: :unprocessable_entity
    elsif @reviews.all?(&:valid?)
      ProductReview.transaction { @reviews.each(&:save!) }
      redirect_to order_path(@order), notice: t(".thanks", count: @reviews.size)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.find_by!(token: params[:order_id])
      @products = @order.reviewable_products.with_attached_images.to_a
      redirect_to order_path(@order), notice: t("orders.reviews.nothing_to_review") if @products.empty?
    end
end
