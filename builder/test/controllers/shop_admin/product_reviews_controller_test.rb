require "test_helper"

class ShopAdmin::ProductReviewsControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup do
    @review = orders(:shipped).product_reviews.create!(product: products(:tee), rating: 1, body: "Buy cheap watches at spam.example", author_name: "Spam")
  end

  test "staff hide a spam review and show it again" do
    sign_in_as users(:cats_staff)
    get shop_admin_product_reviews_path
    assert_response :success
    assert_select "li", /spam\.example/

    patch shop_admin_product_review_path(@review, status: "hidden")
    assert @review.reload.hidden?
    assert_not_includes products(:tee).product_reviews.published, @review

    get shop_admin_product_reviews_path(status: "hidden")
    assert_select "li", /spam\.example/

    patch shop_admin_product_review_path(@review, status: "published")
    assert @review.reload.published?
  end

  test "signed out goes to sign in" do
    get shop_admin_product_reviews_path
    assert_redirected_to new_session_path(shop_id: nil)
  end
end
