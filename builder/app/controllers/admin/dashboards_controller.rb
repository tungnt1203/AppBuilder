# The owner's admin over all their shops (/admin): the last 30 days across them, what needs
# action, and the latest orders, from each app's own summary (ShopOrders, refreshed every
# quarter hour and with "Refresh").
class Admin::DashboardsController < ApplicationController
  def show
    @projects = Current.user.projects.listed.ordered.select { |project| ShopOrders.new(project).applicable? || project.orders_summary }
    summaries = @projects.filter_map { |project| [ project, project.orders_summary ] if project.orders_summary && project.orders_summary["errors"].blank? }
    @totals = summaries.group_by { |_, summary| summary["currency"] }.transform_values do |pairs|
      %w[ sales_cents orders needs_action problems margin_cents ].index_with { |key| pairs.sum { |_, summary| summary[key].to_i } }
    end
    @orders = summaries.flat_map { |project, summary| Array(summary["recent"]).map { |order| order.merge("project" => project) } }
      .sort_by { |order| order["placed_at"].to_s }.reverse.first(40)
  end
end
