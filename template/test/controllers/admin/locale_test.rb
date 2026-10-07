require "test_helper"

# A Vietnamese owner selling to English-speaking buyers: the site in English, /admin in Vietnamese.
class Admin::LocaleTest < ActionDispatch::IntegrationTest
  setup do
    @admin_locale = Rails.configuration.x.admin_locale
    Rails.configuration.x.admin_locale = :vi
  end

  teardown { Rails.configuration.x.admin_locale = @admin_locale }

  test "/admin speaks the owner's language and the site the buyers'" do
    sign_in_as users(:owner)

    get admin_orders_path
    assert_select "h1", "Đơn hàng"

    get products_path
    assert_select "h1", "Shop"
  end

  test "emails to staff are in the owner's language, to buyers in theirs" do
    assert_match "Đơn hàng mới", Admin::OrderMailer.placed(orders(:pending)).subject
    assert_match "confirmed", OrderMailer.confirmation(orders(:pending)).subject
  end
end
