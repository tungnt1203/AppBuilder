require "test_helper"

class PoliciesControllerTest < ActionDispatch::IntegrationTest
  test "a policy is public once the owner saves it, and linked in the footer" do
    get policy_path("refund")
    assert_response :not_found

    sign_in_as users(:owner)
    get edit_admin_policies_path
    assert_response :success
    assert_select "textarea[name='store[refund_policy]']", /made to order/
    assert_match "hello@example.com", response.body

    patch admin_policies_path, params: { store: { refund_policy: "Intro.\n\n## Damaged items\n\n- Email us\n- Get a reprint", contact_phone: "+1 212 555 0142" } }
    assert_redirected_to edit_admin_policies_path

    get policy_path("refund")
    assert_select "h1", "Refund policy"
    assert_select "h2", "Damaged items"
    assert_select "li", "Get a reprint"
    assert_select "footer a[href='#{policy_path("refund")}']"
    assert_select "footer a[href='#{policy_path("privacy")}']", count: 0
  end

  test "unknown policies aren't found" do
    get policy_path("cookies")
    assert_response :not_found
  end

  test "the contact page shows how to reach the shop" do
    Store.current.update!(contact_phone: "+1 212 555 0142", business_address: "1 Main St\nPortland, OR")
    get contact_path
    assert_select "a[href='mailto:hello@example.com']"
    assert_select "a[href='tel:+12125550142']"
    assert_select "dd", /Portland, OR/
  end

  test "the checkout links the terms the buyer agrees to" do
    Store.current.update!(terms_of_service: "Terms.")
    post cart_items_path, params: { variant_id: variants(:mug).id }
    get new_checkout_path
    assert_select "a[href='#{policy_path("terms")}']", "Terms of service"
  end
end
