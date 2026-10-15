# Buyers review what they bought once it's on its way: stars and a few words for each product
# (the order's reviewable_products), under the name they choose. One review per product.
class StorefrontApi::V1::Orders::ReviewsController < StorefrontApi::V1::BaseController
  def create
    order = Order.find_by!(token: params[:order_id])
    products = order.reviewable_products.index_by(&:slug)
    reviews = Array(params.require(:reviews)).filter_map do |fields|
      fields = fields.permit(:product_slug, :rating, :body)
      product = products[fields[:product_slug]] or next
      order.product_reviews.build(product:, rating: fields[:rating], body: fields[:body], author_name: params[:author_name].presence || ProductReview.default_author_name(order.shipping_name))
    end

    if reviews.empty?
      error :nothing_to_review, "Nothing here to review: pick stars for a product of the order that hasn't been reviewed", status: :unprocessable_entity
    elsif (invalid_review = reviews.find(&:invalid?))
      invalid invalid_review
    else
      ProductReview.transaction { reviews.each(&:save!) }
      render json: { reviews: reviews.map { |review| json.review(review).merge(product_slug: review.product.slug) } }, status: :created
    end
  end
end
