# Brings one app's orders at a glance (the shop core's OrdersSummary) into the builder, for the
# owner's board of all their shops' orders: from its published copy when it has one (real
# buyers), else from its preview (orders placed while trying it).
class ShopOrders
  MARKER = "ORDERS_SUMMARY_RESULT"

  def initialize(project)
    @project = project
  end

  def applicable?
    (@project.ready? || @project.working?) && @project.path.join("config/application.rb").exist?
  end

  def refresh
    return unless applicable?

    source = @project.deployments.live.exists? ? "live" : "preview"
    summary = AppTask.new(@project).run("shop:orders_summary", marker: MARKER, copy: source.to_sym)
    @project.update!(orders_summary: summary, orders_summary_at: Time.current, orders_summary_source: source)
    summary
  end

  # Where staff open one of its orders: the published shop's /admin, or the app in the studio.
  def self.order_url(project, token)
    project.orders_summary_source == "live" ? "#{project.publish_url}/admin/orders/#{token}" : nil
  end
end
