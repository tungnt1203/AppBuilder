# The board of all the shops someone runs (/admin): the last 30 days across them, what needs
# action, and the latest orders, read from each shop's data (OrdersSummary).
class Admin::DashboardsController < Admin::BaseController
  def show
    @shops = Current.user.shops.order(:name).to_a
    @summaries = @shops.index_with { |shop| ActsAsTenant.with_tenant(shop) { OrdersSummary.new.to_h } }
    @totals = @summaries.values.group_by { |summary| summary["currency"] }.transform_values do |summaries|
      %w[ sales_cents orders needs_action problems margin_cents ].index_with { |key| summaries.sum { |summary| summary[key].to_i } }
    end
    @orders = @summaries.flat_map { |shop, summary| summary["recent"].map { |order| order.merge("shop" => shop) } }
      .sort_by { |order| order["placed_at"] }.reverse.first(40)
  end
end
