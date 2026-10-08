require "test_helper"

class Agent::MerchantTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "Authorization" => "Bearer #{Store.current.generate_agent_key!("merchant")}", "X-Agent-Operator" => "olivia" }
  end

  test "numbers for a period, and what the shop can't supply" do
    get agent_merchant_snapshot_path(period: "last_30_days"), headers: @headers
    snapshot = response.parsed_body
    assert_equal "last_30_days", snapshot["period"]
    assert_nil snapshot["traffic"]

    get agent_merchant_metrics_path(metric: "sales", period: "last_7_days"), headers: @headers
    assert_operator response.parsed_body["points"].size, :>=, 7

    get agent_merchant_metrics_path(metric: "visits"), headers: @headers
    assert_empty response.parsed_body["points"]
    assert response.parsed_body["note"]

    get agent_merchant_context_path, headers: @headers
    assert_equal %w[ traffic campaigns ], response.parsed_body["limitations"].map { |limitation| limitation["source"] }
  end

  test "listings, low stock and pricing with margins" do
    variants(:tee_black_s).update!(track_inventory: true, inventory_quantity: 2, cost_cents: 1000)

    get agent_merchant_listings_path(query: "tee"), headers: @headers
    assert_equal "product-#{products(:tee).slug}", response.parsed_body["listings"].sole["listing_id"]

    get agent_merchant_inventory_alerts_path, headers: @headers
    assert_includes response.parsed_body["alerts"].map { |alert| alert["listing_id"] }, "variant-#{variants(:tee_black_s).id}"

    get pricing_agent_merchant_listing_path("variant-#{variants(:tee_black_s).id}"), headers: @headers
    assert_equal 58.3, response.parsed_body["margin_pct"]
  end

  test "a price change is staged, changes nothing, and applies on approval" do
    variant = variants(:tee_black_s)
    variant.update!(cost_cents: 2000)
    post agent_merchant_changes_path, params: { kind: "price_update", payload: { items: [ { listing_id: "variant-#{variant.id}", new_price: 19.5 } ] } }, headers: @headers, as: :json

    change = response.parsed_body
    assert_response :created
    assert_equal "staged", change["status"]
    assert_equal [ 24.0, 19.5 ], change["items"].sole.values_at("before", "after")
    assert_match "below its cost", change["guardrail_notes"].sole
    assert_equal 2400, variant.reload.price_cents

    post apply_agent_merchant_change_path(change["change_id"]), headers: @headers
    assert_equal "olivia", response.parsed_body["applied_by"]
    assert_equal 1950, variant.reload.price_cents

    post apply_agent_merchant_change_path(change["change_id"]), headers: @headers
    assert_response :unprocessable_entity
  end

  test "restock, pause, a text edit and a sale" do
    variant = variants(:tee_black_s)
    post agent_merchant_changes_path, params: { kind: "inventory_action", payload: { items: [
      { listing_id: "variant-#{variant.id}", action: "restock", quantity: 10 }, { listing_id: "product-#{products(:mug).slug}", action: "pause" } ] } }, headers: @headers, as: :json
    post apply_agent_merchant_change_path(response.parsed_body["change_id"]), headers: @headers
    assert_equal [ true, 10 ], variant.reload.values_at(:track_inventory, :inventory_quantity)
    assert_not variants(:mug).reload.available?

    post agent_merchant_changes_path, params: { kind: "listing_update", payload: { listing_id: "product-#{products(:tee).slug}", fields: { title: "Cat Mom Tee, organic" } } }, headers: @headers, as: :json
    post apply_agent_merchant_change_path(response.parsed_body["change_id"]), headers: @headers
    assert_equal "Cat Mom Tee, organic", products(:tee).reload.title

    post agent_merchant_changes_path, params: { kind: "promotion", payload: { name: "Weekend", listing_ids: [ "product-#{products(:tee).slug}" ],
      discount_pct: 20, starts: Date.current.iso8601, ends: (Date.current + 2).iso8601 } }, headers: @headers, as: :json
    assert_equal products(:tee).variants.count, response.parsed_body["items"].size
    post apply_agent_merchant_change_path(response.parsed_body["change_id"]), headers: @headers
    assert Promotion.find_by!(name: "Weekend").active?
    assert_equal 1920, variant.reload.price_cents
  end

  test "what the shop doesn't manage is refused, saying why; discarding stamps who" do
    post agent_merchant_changes_path, params: { kind: "campaign", payload: { name: "Ads" } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "not_applicable", response.parsed_body["error"]

    post agent_merchant_changes_path, params: { kind: "listing_update", payload: { listing_id: "product-#{products(:tee).slug}", fields: { brand: "X" } } }, headers: @headers, as: :json
    assert_response :unprocessable_entity

    post agent_merchant_changes_path, params: { kind: "price_update", payload: { items: [ { listing_id: "product-#{products(:tee).slug}", new_price: 10 } ] } }, headers: @headers, as: :json
    assert_response :not_found, "a family is repriced one variant at a time"

    post agent_merchant_changes_path, params: { kind: "price_update", payload: { items: [ { listing_id: "variant-#{variants(:mug).id}", new_price: 12 } ] } }, headers: @headers, as: :json
    post discard_agent_merchant_change_path(response.parsed_body["change_id"]), params: { actor_kind: "agent" }, headers: @headers
    assert_equal [ "discarded", "olivia", "agent" ], response.parsed_body.values_at("status", "discarded_by", "discarded_by_kind")
  end
end
