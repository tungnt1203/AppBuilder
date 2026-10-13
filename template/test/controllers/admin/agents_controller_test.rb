require "test_helper"

class Admin::AgentsControllerTest < ActionDispatch::IntegrationTest
  test "admins make a key, see it once, and disconnect it" do
    sign_in_as users(:admin)
    post admin_agents_path(role: "merchant")
    follow_redirect!
    key = css_select("input[aria-label='Agent key']").first["value"]
    assert Store.current.agent_key_valid?("merchant", key)

    get admin_agents_path
    assert_select "input[aria-label='Agent key']", count: 0

    delete admin_agents_path(role: "merchant")
    assert_not Store.current.agent_key?("merchant")
  end

  test "staff can't" do
    sign_in_as users(:staff)
    post admin_agents_path(role: "storefront")
    assert_not Store.current.agent_key?("storefront")
  end

  test "staff apply or discard the assistant's suggestions" do
    sign_in_as users(:staff)
    change = AgentChange.stage!("price_update", { items: [ { listing_id: "variant-#{variants(:mug).id}", new_price: 12 } ] }, by: "olivia")

    get admin_agent_changes_path
    assert_select "p", "Morning Mug: $15.00 → $12.00"
    assert_select "li", /Morning Mug · Price\s*\$15.00 → \$12.00/

    post admin_agent_change_application_path(change)
    assert change.reload.applied?
    assert_equal "Sam Staff", change.applied_by
    assert_equal 1200, variants(:mug).reload.price_cents

    other = AgentChange.stage!("price_update", { items: [ { listing_id: "variant-#{variants(:mug).id}", new_price: 99 } ] }, by: "olivia")
    post admin_agent_change_discard_path(other)
    assert other.reload.discarded?
  end

  test "a paused product reads as the product, not its id" do
    sign_in_as users(:owner)
    AgentChange.stage!("inventory_action", { items: [ { listing_id: "variant-#{variants(:mug).id}", action: "pause" } ] }, by: "olivia")

    get admin_agent_changes_path
    assert_select "p", "Pause Morning Mug"
    assert_select "li", /For sale\s*Yes → No/
  end
end
