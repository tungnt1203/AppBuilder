require "test_helper"

class Admin::PromotionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:staff) }

  test "a sale that starts now lowers the prices at once; ending it puts them back" do
    variant = variants(:tee_black_s)
    post admin_promotions_path, params: { promotion: { name: "Flash", percent_off: 50, starts_at: 1.minute.ago.strftime("%Y-%m-%dT%H:%M"),
      ends_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"), variant_ids: [ "", variant.id ] } }

    promotion = Promotion.find_by!(name: "Flash")
    assert_redirected_to admin_promotions_path
    assert promotion.active?
    assert_equal 1200, variant.reload.price_cents

    post admin_promotion_cancellation_path(promotion)
    assert promotion.reload.cancelled?
    assert_equal 2400, variant.reload.price_cents
  end

  test "lists sales" do
    get new_admin_promotion_path
    assert_response :success
    get admin_promotions_path
    assert_response :success
  end
end
