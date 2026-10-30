require "test_helper"

class ShopAdmin::AdSpendsControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_staff) }

  test "staff enter a day's spend per source, enter it again to correct it, and remove it" do
    get shop_admin_ad_spends_path
    assert_response :success
    assert_select "datalist option[value=tiktok]"

    post shop_admin_ad_spends_path, params: { ad_spend: { date: Date.yesterday, source: " TikTok ", amount: "45.50" } }
    assert_redirected_to shop_admin_ad_spends_path
    post shop_admin_ad_spends_path, params: { ad_spend: { date: Date.yesterday, source: "tiktok", amount: "50" } }
    spend = AdSpend.sole
    assert_equal [ "tiktok", 5000 ], [ spend.source, spend.amount_cents ]

    get shop_admin_root_path
    assert_select "p", /Return on ad spend/
    assert_select "p", /\$50\.00 on ads/ # no tiktok sales, but its spend shows by its source

    delete shop_admin_ad_spend_path(spend)
    assert_empty AdSpend.all
  end

  test "a day still to come or a made-up amount isn't saved" do
    post shop_admin_ad_spends_path, params: { ad_spend: { date: 2.days.from_now.to_date, source: "facebook", amount: "abc" } }
    assert_response :unprocessable_entity
    assert_select "li", /can't be a day still to come/
    assert_empty AdSpend.all
  end
end
