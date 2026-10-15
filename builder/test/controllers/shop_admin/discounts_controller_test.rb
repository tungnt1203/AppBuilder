require "test_helper"

class ShopAdmin::DiscountsControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "lists, creates, edits and deletes codes" do
    get shop_admin_discounts_path
    assert_select "a[href=?]", edit_shop_admin_discount_path(discounts(:welcome))

    post shop_admin_discounts_path, params: { discount: { code: "launch 20", kind: "percentage", percent_off: 20, usage_limit: 50, active: "1" } }
    assert_equal 50, Discount.find_by!(code: "LAUNCH20").usage_limit, "spaces are dropped, letters capitalized"

    post shop_admin_discounts_path, params: { discount: { code: "50% OFF", kind: "percentage", percent_off: 50 } }
    assert_response :unprocessable_entity

    post shop_admin_discounts_path, params: { discount: { code: "launch-20", kind: "fixed_amount", amount_off: "7.50", active: "1" } }
    discount = Discount.find_by!(code: "LAUNCH-20")
    assert_equal 750, discount.amount_off_cents

    patch shop_admin_discount_path(discount), params: { discount: { active: "0" } }
    assert_not discount.reload.active?

    delete shop_admin_discount_path(discount)
    assert_not Discount.exists?(discount.id)
  end
end
