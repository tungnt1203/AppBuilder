require "test_helper"

# Every screen of a shop's admin opens for its members, inside that shop only.
class ShopAdmin::ScreensTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:member) }

  test "each screen of the shop opens" do
    shop = shops(:cats)
    in_shop(shop)
    product, order, collection, discount = products(:tee), orders(:paid), collections(:cats), discounts(:welcome)
    ActsAsTenant.current_tenant = nil

    [ shop_admin_root_path(shop), shop_admin_orders_path(shop), shop_admin_order_path(shop, order),
      shop_admin_products_path(shop), new_shop_admin_product_path(shop), edit_shop_admin_product_path(shop, product),
      shop_admin_collections_path(shop), new_shop_admin_collection_path(shop), edit_shop_admin_collection_path(shop, collection),
      shop_admin_discounts_path(shop), new_shop_admin_discount_path(shop), edit_shop_admin_discount_path(shop, discount),
      shop_admin_promotions_path(shop), new_shop_admin_promotion_path(shop), shop_admin_product_reviews_path(shop),
      edit_shop_admin_settings_path(shop), edit_shop_admin_policies_path(shop), edit_shop_admin_theme_setting_path(shop),
      edit_shop_admin_custom_fields_path(shop), shop_admin_pages_path(shop), new_shop_admin_page_path(shop),
      shop_admin_menus_path(shop), new_shop_admin_menu_path(shop), shop_admin_forms_path(shop), new_shop_admin_form_path(shop),
      shop_admin_printify_connection_path(shop),
      shop_admin_memberships_path(shop), new_shop_admin_membership_path(shop) ].each do |path|
      get path
      assert_response :success, path
      assert_select "aside summary", /Chubby Cat Tees/
    end
  end

  test "a preview's test orders say so" do
    in_shop(shops(:cats))
    orders(:paid).update!(test: true)
    ActsAsTenant.current_tenant = nil
    get shop_admin_orders_path(shops(:cats))
    assert_select "li", /#1002.*Test/m
  end
end
