# Discount codes buyers enter in the cart.
class Admin::DiscountsController < Admin::BaseController
  before_action :set_discount, only: %i[ edit update destroy ]

  def index
    @discounts = Discount.ordered
  end

  def new
    @discount = Discount.new(kind: "percentage", percent_off: 10)
  end

  def create
    @discount = Discount.new(discount_params)

    if @discount.save
      redirect_to admin_discounts_path, notice: t(".notice", code: @discount.code)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @discount.update(discount_params)
      redirect_to admin_discounts_path, notice: t(".notice", code: @discount.code)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Orders that used it keep the code and the amount it took off.
  def destroy
    @discount.destroy!
    redirect_to admin_discounts_path, notice: t(".notice", code: @discount.code), status: :see_other
  end

  private
    def set_discount
      @discount = Discount.find(params[:id])
    end

    def discount_params
      params.expect(discount: %i[ code kind percent_off amount_off minimum_subtotal starts_at ends_at usage_limit active ])
    end
end
