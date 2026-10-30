# Every hour, for each shop where it's now 8 in the morning: yesterday in one email to its owners
# and admins (Admin::SummaryMailer), when anything happened (an order or a visitor).
class Shop::DailySummaryJob < ApplicationJob
  HOUR = 8

  def perform(now: Time.current)
    Shop.each_in_turn do
      shop = ActsAsTenant.current_tenant
      local = now.in_time_zone(shop.time_zone)
      next unless local.hour == HOUR

      date = local.to_date - 1
      report = ShopReport.new(period: "1", time_zone: shop.time_zone, now: local - 1.day)
      next if report.totals.orders.zero? && report.funnel["visit"].zero?

      Admin::SummaryMailer.daily(shop, date.iso8601).deliver_later
    end
  end
end
