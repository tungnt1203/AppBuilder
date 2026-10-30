# A shop's day for its owners and admins, each morning (Shop::DailySummaryJob): sales and orders
# against the day before, what's left after printing and ads, the best sellers, the funnel, and
# what's waiting on them.
class Admin::SummaryMailer < ApplicationMailer
  helper :money

  def daily(shop, date)
    recipients = shop.memberships.where(role: %w[ owner admin ]).joins(:user).pluck("users.email_address")
    return if recipients.empty?

    ActsAsTenant.with_tenant(shop) do
      @shop, @date = shop, Date.iso8601(date)
      @report = ShopReport.new(period: "1", time_zone: shop.time_zone, now: @date.in_time_zone(shop.time_zone).noon)
      @store = Store.current
      @to_ship = Order.where(status: %w[ paid in_production ]).count
      mail to: recipients, subject: t(".subject", shop: shop.name, sales: ApplicationController.helpers.money(@report.totals.sales_cents, @store.currency), count: @report.totals.orders)
    end
  end
end
