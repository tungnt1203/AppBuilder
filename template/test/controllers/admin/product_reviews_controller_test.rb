require "test_helper"

class Admin::ProductReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @review = orders(:shipped).product_reviews.create!(product: products(:tee), rating: 1, body: "Buy cheap watches at spam.example", author_name: "Spam")
  end

  test "staff hide a spam review and show it again" do
    sign_in_as users(:staff)
    get admin_product_reviews_path
    assert_response :success
    assert_select "li", /spam\.example/

    patch admin_product_review_path(@review, status: "hidden")
    assert @review.reload.hidden?
    get product_path(products(:tee))
    assert_select "#reviews", 0

    get admin_product_reviews_path(status: "hidden")
    assert_select "li", /spam\.example/

    patch admin_product_review_path(@review, status: "published")
    assert @review.reload.published?
  end

  test "signed out goes to sign in" do
    get admin_product_reviews_path
    assert_redirected_to new_admin_session_path
  end
end
