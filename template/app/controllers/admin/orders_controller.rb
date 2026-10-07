class Admin::OrdersController < Admin::BaseController
  # Card checkouts the buyer hasn't paid yet show only under All.
  FILTERS = {
    "open" => -> { Order.needs_action },
    "pending" => -> { Order.awaiting_payment },
    "to_ship" => -> { Order.where(status: %w[ paid in_production ]) },
    "shipped" => -> { Order.where(status: %w[ shipped delivered ]) },
    "closed" => -> { Order.where(status: %w[ cancelled refunded ]) }
  }.freeze

  before_action :set_order, only: %i[ show update ]

  def index
    @filter = FILTERS.key?(params[:filter]) ? params[:filter] : nil
    scope = Order.search(params[:q]).newest_first.includes(:line_items)
    scope = scope.merge(FILTERS[@filter].call) if @filter
    @page = paginate(scope, per: 50)
    @counts = FILTERS.transform_values { |filter| filter.call.count }
  end

  def show
  end

  # Staff notes, and contact and address corrections.
  def update
    if @order.update(order_params)
      @order.record :edited, by: Current.user
      redirect_to admin_order_path(@order), notice: t(".notice")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_order
      @order = Order.includes(:line_items, events: :user).find_by!(token: params[:id])
    end

    def order_params
      params.expect(order: [ :staff_note, :email, :phone, :shipping_name, :shipping_address1, :shipping_address2,
        :shipping_city, :shipping_region, :shipping_postal_code, :shipping_country ])
    end
end
