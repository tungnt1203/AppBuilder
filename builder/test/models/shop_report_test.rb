require "test_helper"

class ShopReportTest < ActiveSupport::TestCase
  setup do
    in_shop
    orders(:paid).update_columns(created_at: 2.days.ago, attribution: { "source" => "tiktok" }, fulfillment_cost_cents: 900, tax_cents: 100)
    orders(:shipped).update_columns(created_at: 40.days.ago, attribution: { "fbc" => "fb.1.2.abc" })
  end

  test "totals the period's paid orders against the period before, less refunds, tax and printing" do
    report = ShopReport.new(period: "30")

    assert_equal 2000, report.totals.sales_cents, "the pending order isn't a sale"
    assert_equal 1, report.totals.orders
    assert_equal 1000, report.totals.left_cents
    assert_equal 4800, report.previous.sales_cents
    assert_in_delta(-0.583, report.change(:sales_cents), 0.001)

    orders(:paid).update_columns(refunded_cents: 500)
    assert_equal 1500, ShopReport.new(period: "30").totals.sales_cents
  end

  test "a day for each day of the period, in the shop's time zone, with nothing on quiet days" do
    days = ShopReport.new(period: "7", time_zone: "Asia/Ho_Chi_Minh").by_day

    assert_equal 7, days.size
    assert_equal Time.current.in_time_zone("Asia/Ho_Chi_Minh").to_date, days.last.date
    assert_equal [ 2000 ], days.map(&:sales_cents).select(&:positive?)
    assert_equal 1, days.sum(&:orders)
  end

  test "best sellers by sales, and sales by where buyers came from" do
    report = ShopReport.new(period: "90")

    assert_equal [ [ "facebook", 4800, 1, 0 ], [ "tiktok", 2000, 1, 0 ] ], report.sources.map(&:to_h).map(&:values)
    assert_equal [ [ "Cat Mom Tee", 2, 4800 ], [ "Morning Mug", 1, 1500 ] ], report.top_products.map { |line| [ line.title, line.quantity, line.sales_cents ] }
  end

  test "ad spend gives the return on it and the profit after it, per source too" do
    AdSpend.create!(date: 3.days.ago.to_date, source: "tiktok", amount_cents: 800)
    AdSpend.create!(date: 1.day.ago.to_date, source: "google", amount_cents: 200)
    AdSpend.create!(date: 50.days.ago.to_date, source: "tiktok", amount_cents: 999)
    report = ShopReport.new(period: "30")

    assert_equal 1000, report.ad_spend
    assert_in_delta 2.0, report.return_on_ad_spend
    assert_equal 0, report.profit_cents, "left 1000 after tax and printing, less 1000 on ads"
    tiktok, google = report.sources
    assert_equal [ "tiktok", 2000, 800, 2.5 ], [ tiktok.name, tiktok.sales_cents, tiktok.spent_cents, tiktok.return_on_ad_spend ]
    assert_equal [ "google", 0, 200 ], [ google.name, google.sales_cents, google.spent_cents ], "spend with no sales still shows"
  end

  test "an unknown period is thirty days" do
    assert_equal 30, ShopReport.new(period: "1000").days
  end
end
