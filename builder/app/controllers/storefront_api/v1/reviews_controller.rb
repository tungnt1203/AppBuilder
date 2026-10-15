# A product's published reviews, newest first, with its rating.
class StorefrontApi::V1::ReviewsController < StorefrontApi::V1::BaseController
  PER_PAGE = 10

  def index
    product = Product.visible.find_by!(slug: params[:product_id])
    reviews = product.product_reviews.published.newest_first
    page = params.fetch(:page, 1).to_i.clamp(1, 1000)
    render json: { rating: product.rating_summary, reviews: reviews.limit(PER_PAGE).offset((page - 1) * PER_PAGE).map { |review| json.review(review) },
      page:, per_page: PER_PAGE, total: reviews.count }
  end
end
