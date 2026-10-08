require "test_helper"

class Admin::DiscountsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:staff) }

  test "lists, creates, edits and deletes codes" do
    get admin_discounts_path
    assert_select "a[href=?]", edit_admin_discount_path(discounts(:welcome))

    post admin_discounts_path, params: { discount: { code: "launch 20", kind: "percentage", percent_off: 20, usage_limit: 50, active: "1" } }
    assert_equal 50, Discount.find_by!(code: "LAUNCH20").usage_limit, "spaces are dropped, letters capitalized"

    post admin_discounts_path, params: { discount: { code: "50% OFF", kind: "percentage", percent_off: 50 } }
    assert_response :unprocessable_entity

    post admin_discounts_path, params: { discount: { code: "launch-20", kind: "fixed_amount", amount_off: "7.50", active: "1" } }
    discount = Discount.find_by!(code: "LAUNCH-20")
    assert_equal 750, discount.amount_off_cents

    patch admin_discount_path(discount), params: { discount: { active: "0" } }
    assert_not discount.reload.active?

    delete admin_discount_path(discount)
    assert_not Discount.exists?(discount.id)
  end
end
