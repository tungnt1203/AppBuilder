class Agent::Merchant::ReportsController < Agent::Merchant::BaseController
  def context
    render json: merchant.context
  end

  def snapshot
    render json: merchant.snapshot(params[:period])
  end

  def metrics
    render json: merchant.metric(params.require(:metric), period: params[:period], granularity: params.fetch(:granularity, "day"), segment: params[:segment])
  end

  def inventory_alerts
    render json: { alerts: merchant.inventory_alerts }
  end

  def order_issues
    render json: { issues: merchant.order_issues }
  end

  # Campaigns run outside the shop (see the context's limitations).
  def campaigns
    render json: { campaigns: [] }
  end
end
