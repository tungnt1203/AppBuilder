require "test_helper"

class Orders::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.delete_all
    @order = orders(:shipped)
  end

  test "a buyer reviews what they bought from their order's link, and it shows on the product page" do
    get order_path(@order)
    assert_select "a[href=?]", new_order_review_path(@order)

    get new_order_review_path(@order)
    assert_response :success
    assert_select "input[name=author_name][value='Sam B.']"
    assert_select "input[name='reviews[#{products(:tee).id}][rating]']", 5

    post order_review_path(@order), params: { author_name: "Sam from Portland", reviews: { products(:tee).id => { rating: "5", body: "Soft, and the print held up in the wash." } } }
    assert_redirected_to order_path(@order)
    review = @order.product_reviews.sole
    assert_equal [ 5, "Sam from Portland", products(:tee) ], [ review.rating, review.author_name, review.product ]

    get product_path(products(:tee))
    assert_select "#reviews li", 1
    assert_select "#reviews", /Soft, and the print held up/
    assert_select "#reviews", /Verified buyer/
    data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal({ "@type" => "AggregateRating", "ratingValue" => 5.0, "reviewCount" => 1 }, data["aggregateRating"])
    assert_equal "Sam from Portland", data["review"].sole.dig("author", "name")

    get new_order_review_path(@order)
    assert_redirected_to order_path(@order)
  end

  test "without stars nothing is posted" do
    post order_review_path(@order), params: { author_name: "Sam", reviews: { products(:tee).id => { rating: "", body: "Nice" } } }
    assert_response :unprocessable_entity
    assert_select "textarea", text: "Nice"
    assert_empty @order.product_reviews
  end

  test "orders not on their way yet, and other products, can't be reviewed" do
    get new_order_review_path(orders(:paid))
    assert_redirected_to order_path(orders(:paid))

    post order_review_path(@order), params: { author_name: "Sam", reviews: { products(:mug).id => { rating: "1" } } }
    assert_response :unprocessable_entity
    assert_empty ProductReview.all
  end

  test "odd form data and a double tap don't break anything" do
    post order_review_path(@order), params: { author_name: "Sam", reviews: "x" }
    assert_response :unprocessable_entity
    post order_review_path(@order), params: { author_name: "Sam", reviews: { products(:tee).id => "5" } }
    assert_response :unprocessable_entity

    # The other tap saved it between this one's checks and its save.
    ProductReview.define_singleton_method(:transaction) { |*| raise ActiveRecord::RecordNotUnique }
    post order_review_path(@order), params: { author_name: "Sam", reviews: { products(:tee).id => { rating: "5" } } }
    assert_redirected_to order_path(@order)
  ensure
    ProductReview.singleton_class.remove_method(:transaction) if ProductReview.singleton_methods(false).include?(:transaction)
  end

  test "an order is found by its token only" do
    get new_order_review_path(@order.id)
    assert_response :not_found
  end

  test "a product without reviews shows no stars or section" do
    get product_path(products(:tee))
    assert_select "#reviews", 0
    assert_no_match "AggregateRating", response.body
  end
end
