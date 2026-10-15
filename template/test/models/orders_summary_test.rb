require "test_helper"

class OrdersSummaryTest < ActiveSupport::TestCase
  test "the last 30 days' sales and orders, what needs action, Printify's problems and the latest orders" do
    orders(:paid).update!(fulfillment_error: "Address is invalid")
    summary = OrdersSummary.new.to_h

    assert_equal Order.counted_in_sales.where(created_at: 30.days.ago..).sum(:total_cents), summary["sales_cents"]
    assert_equal Order.needs_action.count, summary["needs_action"]
    assert_equal 1, summary["problems"]
    latest = summary["recent"].find { |order| order["number"] == orders(:paid).number }
    assert_equal [ orders(:paid).token, "paid", "Address is invalid" ], latest.values_at("token", "status", "problem")
    assert_not latest.key?("email"), "buyers by name only"
  end

  test "card checkouts nobody finished aren't orders yet" do
    orders(:pending).update!(payment_method: "stripe")
    assert_not_includes OrdersSummary.new.to_h["recent"].map { |order| order["number"] }, orders(:pending).number
  end
end
