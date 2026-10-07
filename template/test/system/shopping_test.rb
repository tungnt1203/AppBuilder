require "application_system_test_case"

class ShoppingTest < ApplicationSystemTestCase
  test "a visitor buys on a phone without an account, then the owner ships the order" do
    on_phone do
      visit root_path
      click_on "Cat Mom Tee"

      choose "White", allow_label_click: true
      choose "M", allow_label_click: true
      assert_text "$26.00"
      click_on I18n.t("products.show.add_to_cart")

      assert_text I18n.t("cart_items.create.added", product: "Cat Mom Tee")
      assert_text "White / M"
      click_on I18n.t("carts.show.checkout")

      fill_in Order.human_attribute_name(:email), with: "robin@example.com"
      select "United States", from: Order.human_attribute_name(:shipping_country)
      fill_in Order.human_attribute_name(:shipping_name), with: "Robin Buyer"
      fill_in Order.human_attribute_name(:shipping_address1), with: "5 Elm St"
      fill_in Order.human_attribute_name(:shipping_city), with: "Austin"
      click_on I18n.t("checkouts.new.place_order")

      assert_text I18n.t("orders.show.thanks", name: "Robin Buyer")
      assert_text "bank transfer"
    end

    order = Order.last
    assert_equal 2600 + 500, order.total_cents

    sign_in_as users(:owner)
    click_on I18n.t("layouts.admin.orders")
    click_on order.name
    click_on I18n.t("admin.orders.show.mark_paid")
    assert_text I18n.t("admin.orders.payments.create.notice", number: order.name)

    fill_in I18n.t("admin.orders.show.ship.carrier"), with: "USPS"
    fill_in I18n.t("admin.orders.show.ship.tracking_number"), with: "9400 1111"
    click_on I18n.t("admin.orders.show.ship.submit")

    assert_text I18n.t("admin.orders.shipments.create.notice", number: order.name)
    assert order.reload.shipped?
  end

  test "a sold-out option can't be added to the cart" do
    visit product_path(products(:tee))
    choose "White", allow_label_click: true
    choose "S", allow_label_click: true

    assert_text I18n.t("products.show.unavailable")
    assert_button I18n.t("products.show.add_to_cart"), disabled: true
  end

  test "the owner adds a product that shows up on the site" do
    sign_in_as users(:owner)
    click_on I18n.t("layouts.admin.products")
    click_on I18n.t("admin.products.index.new"), match: :first

    fill_in Product.human_attribute_name(:title), with: "Night Owl Tee"
    fill_in Product.human_attribute_name(:base_price), with: "21.50"
    fill_in I18n.t("admin.products.form.option_name", number: 1), with: "Size"
    fill_in "product_option1_values_text", with: "S, M"
    click_on I18n.t("admin.products.form.create")

    assert_text I18n.t("admin.products.create.notice", title: "Night Owl Tee")
    assert_field "product_variants_attributes_1_price", with: "21.50"

    visit product_path(Product.find_by!(title: "Night Owl Tee"))
    assert_text "$21.50"
  end
end
