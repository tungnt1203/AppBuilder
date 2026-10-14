# Every day: buyers whose order arrived a few days ago get one email asking how they like it,
# with a link to review what they bought. Orders never marked delivered count as arrived a while
# after shipping. Old orders (from before the shop had reviews) aren't asked.
class Order::RequestReviewsJob < ApplicationJob
  AFTER_DELIVERY = 3.days
  AFTER_SHIPPING = 14.days
  NOT_OLDER_THAN = 60.days

  def perform
    Order.where(review_requested_at: nil).placed_since(NOT_OLDER_THAN.ago)
      .merge(Order.where(status: "delivered", delivered_at: ..AFTER_DELIVERY.ago).or(Order.where(status: "shipped", shipped_at: ..AFTER_SHIPPING.ago)))
      .find_each do |order|
        order.update_columns(review_requested_at: Time.current)
        OrderMailer.review_request(order).deliver_later if order.reviewable_products.any?
      end
  end
end
