require "test_helper"

class ProductReviewTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { @order = orders(:shipped) }

  test "only a product of the order can be reviewed, once, with 1 to 5 stars" do
    review = @order.product_reviews.create!(product: products(:tee), rating: 5, body: "  Love   it ", author_name: "Sam B.")
    assert_equal "Love it", review.body
    assert review.published?

    assert_not @order.product_reviews.build(product: products(:tee), rating: 4, author_name: "Sam").valid?
    assert_not @order.product_reviews.build(product: products(:mug), rating: 4, author_name: "Sam").valid?
    assert_not orders(:paid).product_reviews.build(product: products(:mug), rating: 6, author_name: "Lee").valid?
    assert_not orders(:paid).product_reviews.build(product: products(:mug), rating: 4, author_name: " ").valid?
  end

  test "buyers review once the order is on its way, each product once" do
    assert_empty orders(:paid).reviewable_products
    assert_equal [ products(:tee) ], @order.reviewable_products.to_a

    @order.product_reviews.create!(product: products(:tee), rating: 4, author_name: "Sam B.")
    assert_empty @order.reviewable_products
  end

  test "the name shown starts as the first name and an initial" do
    assert_equal "Robin B.", ProductReview.default_author_name("robin  buyer")
    assert_equal "Cher", ProductReview.default_author_name("Cher")
    assert_equal "Mary J.", ProductReview.default_author_name("Mary Ann Jones")
  end

  test "the product's rating counts only shown reviews" do
    assert_nil products(:tee).rating_summary

    @order.product_reviews.create!(product: products(:tee), rating: 5, author_name: "Sam B.")
    other = orders(:pending).tap { |order| order.update!(status: "shipped") }
    hidden = other.product_reviews.create!(product: products(:tee), rating: 2, author_name: "Pat B.")
    assert_equal({ average: 3.5, count: 2 }, products(:tee).rating_summary)

    hidden.hide!
    assert_equal({ average: 5.0, count: 1 }, products(:tee).rating_summary)
  end

  test "buyers are asked once, a few days after the order arrived" do
    @order.update!(status: "delivered", delivered_at: 2.days.ago)
    assert_no_enqueued_emails { Order::RequestReviewsJob.perform_now }

    @order.update!(delivered_at: 4.days.ago)
    assert_enqueued_email_with(OrderMailer, :review_request, args: [ @order ]) { Order::RequestReviewsJob.perform_now }
    assert @order.reload.review_requested_at
    assert_no_enqueued_emails { Order::RequestReviewsJob.perform_now }
  end

  test "orders shipped long ago but never marked delivered are asked too; old orders aren't" do
    @order.update!(shipped_at: 15.days.ago)
    assert_enqueued_emails(1) { Order::RequestReviewsJob.perform_now }

    old = orders(:paid).tap { |order| order.update!(status: "delivered", delivered_at: 50.days.ago, created_at: 70.days.ago) }
    assert_no_enqueued_emails { Order::RequestReviewsJob.perform_now }
    assert_nil old.reload.review_requested_at
  end

  test "the email links to the order's review page" do
    email = OrderMailer.review_request(@order)
    assert_equal [ "sam@example.com" ], email.to
    assert_includes email.text_part.body.to_s, "Cat Mom Tee"
    assert_includes email.text_part.body.to_s, "/orders/#{@order.token}/review/new"
  end
end
