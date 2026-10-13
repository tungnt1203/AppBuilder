require "application_system_test_case"

class AdminOffersTest < ApplicationSystemTestCase
  setup { sign_in_as users(:owner) }

  test "a sale takes a whole product with one tick" do
    visit new_admin_promotion_path
    fill_in Promotion.human_attribute_name(:name), with: "Weekend"
    check "Cat Mom Tee"
    click_on I18n.t("admin.promotions.new.create")

    assert_text I18n.t("admin.promotions.create.notice", name: "Weekend")
    assert_equal products(:tee).variants.ids.sort, Promotion.find_by!(name: "Weekend").variant_ids.sort
  end

  test "a discount code shows only the amount its type needs" do
    visit new_admin_discount_path
    assert_field Discount.human_attribute_name(:percent_off)
    assert_no_field Discount.human_attribute_name(:amount_off)

    select I18n.t("admin.discounts.form.kinds.fixed_amount"), from: Discount.human_attribute_name(:kind)
    assert_field Discount.human_attribute_name(:amount_off)
    assert_no_field Discount.human_attribute_name(:percent_off)

    select I18n.t("admin.discounts.form.kinds.free_shipping"), from: Discount.human_attribute_name(:kind)
    assert_no_field Discount.human_attribute_name(:amount_off)
  end
end
