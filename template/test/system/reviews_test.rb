require "application_system_test_case"

class ReviewsTest < ApplicationSystemTestCase
  test "a buyer rates what they got on a phone, and it shows on the product page; staff can hide spam" do
    order = orders(:shipped)

    on_phone do
      visit order_path(order)
      click_on "Write a review"

      click_on "Post review"
      assert_text "Tap the stars"

      find("label[title='4 stars']").click
      fill_in "What did you think?", with: "Great print, runs a little small."
      fill_in "Name shown with your review", with: "Sam P."
      click_on "Post review"
      assert_text "Thanks for your review!"

      visit product_path(products(:tee))
      click_on "1 review"
      within("#reviews") do
        assert_text "Great print, runs a little small."
        assert_text "Sam P."
      end
    end

    sign_in_as users(:staff)
    visit admin_product_reviews_path
    accept_confirm { click_on "Hide" }
    assert_text "The review is hidden."
    assert order.product_reviews.sole.hidden?
  end
end
