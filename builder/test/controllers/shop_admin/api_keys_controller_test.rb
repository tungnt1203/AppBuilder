require "test_helper"

class ShopAdmin::ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_admin) }

  test "makes a key, shows it once, and revokes it" do
    post shop_admin_api_keys_path, params: { api_key: { kind: "preview" } }
    follow_redirect!
    token = css_select("input[readonly]").first["value"]
    assert_match(/\Ask_preview_/, token)
    assert ShopApiKey.authenticate(token)

    get shop_admin_api_keys_path
    assert_select "input[readonly]", 0
    assert_select "li", /Preview …#{token.last(4)}/

    delete shop_admin_api_key_path(ShopApiKey.sole)
    assert_nil ShopApiKey.authenticate(token)
  end

  test "staff can't make keys" do
    sign_in_as users(:cats_staff)
    post shop_admin_api_keys_path, params: { api_key: { kind: "storefront" } }
    assert_redirected_to shop_admin_root_path
    assert_equal 0, ShopApiKey.count
  end
end
