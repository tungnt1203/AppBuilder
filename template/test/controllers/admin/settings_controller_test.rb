require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "only admins change settings" do
    sign_in_as users(:staff)
    get edit_admin_settings_path
    assert_redirected_to admin_root_path
  end

  test "changes currency, shipping and countries" do
    sign_in_as users(:admin)
    get edit_admin_settings_path
    assert_response :success

    patch admin_settings_path, params: { store: { currency: "EUR", shipping_first_item: "4.5", shipping_additional_item: "1",
      free_shipping_threshold: "", ship_to_countries_text: "de, fr", payment_instructions: "IBAN …" } }

    assert_redirected_to edit_admin_settings_path
    store = Store.current
    assert_equal [ "EUR", 450, 100, nil, %w[ DE FR ] ],
      [ store.currency, store.shipping_first_item_cents, store.shipping_additional_item_cents, store.free_shipping_threshold_cents, store.ship_to_countries ]
  end

  test "mistakes show the form again" do
    sign_in_as users(:owner)
    patch admin_settings_path, params: { store: { currency: "XYZ" } }
    assert_response :unprocessable_entity
  end
end
