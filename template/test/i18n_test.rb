require "test_helper"

class I18nScreensTest < ActionDispatch::IntegrationTest
  setup { enable_customer_accounts }

  test "built-in screens have no missing translations" do
    [ root_path, new_session_path, new_registration_path, new_password_path, new_admin_session_path, new_admin_password_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as_customer customers(:casey)
    [ account_path, edit_account_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    sign_in_as users(:owner)
    [ admin_root_path, admin_users_path, new_admin_user_path, edit_admin_user_path(users(:staff)), admin_user_path(users(:staff)),
      admin_discounts_path, new_admin_discount_path, edit_admin_discount_path(discounts(:five_off)), admin_promotions_path, new_admin_promotion_path,
      edit_admin_product_path(products(:tee)), edit_admin_settings_path, admin_agents_path, admin_agent_changes_path, admin_product_reviews_path,
      admin_printify_connection_path ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end
  end

  test "review screens have no missing translations" do
    order = orders(:shipped)
    [ order_path(order), new_order_review_path(order) ].each do |path|
      get path
      assert_response :success
      assert_no_missing_translations
    end

    order.product_reviews.create!(product: products(:tee), rating: 4, body: "Nice", author_name: "Sam B.")
    get product_path(products(:tee))
    assert_no_missing_translations
  end

  private
    def assert_no_missing_translations
      assert_no_match(/translation[ _]missing/i, response.body, "Missing translation on #{request.path}")
    end
end
