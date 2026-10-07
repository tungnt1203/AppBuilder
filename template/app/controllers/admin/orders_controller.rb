class Admin::OrdersController < Admin::BaseController
  FILTERS = {
    "open" => %w[ pending paid in_production ],
    "pending" => %w[ pending ],
    "to_ship" => %w[ paid in_production ],
    "shipped" => %w[ shipped delivered ],
    "closed" => %w[ cancelled refunded ]
  }.freeze

  before_action :set_order, only: %i[ show update ]

  def index
    @filter = FILTERS.key?(params[:filter]) ? params[:filter] : nil
    scope = Order.search(params[:q]).newest_first.includes(:line_items)
    scope = scope.where(status: FILTERS[@filter]) if @filter
    @page = paginate(scope, per: 50)
    @counts = FILTERS.transform_values { |statuses| Order.where(status: statuses).count }
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
