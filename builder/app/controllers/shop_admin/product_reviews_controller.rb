# Buyers' reviews (ProductReview): staff read them and hide the ones that are spam, offensive or
# not about the product, or show them again.
class ShopAdmin::ProductReviewsController < ShopAdmin::BaseController
  def index
    @hidden = params[:status] == "hidden"
    reviews = ProductReview.newest_first.includes(:product, :order)
    @page = paginate(@hidden ? reviews.hidden : reviews.published)
    @hidden_count = ProductReview.hidden.count
  end

  def update
    review = ProductReview.find(params[:id])
    params[:status] == "hidden" ? review.hide! : review.publish!
    redirect_back_or_to shop_admin_product_reviews_path, notice: t(".#{review.status}")
  end
end
