# The shop's sets of pictures buyers pick from (ClipartSet): made with a name and its first
# pictures, then grown, renamed or deleted; any product's choice field can offer one.
class ShopAdmin::ClipartSetsController < ShopAdmin::BaseController
  before_action :set_clipart_set, only: %i[ show edit update destroy ]

  def index
    @clipart_sets = ClipartSet.ordered.with_attached_pictures
  end

  def show
    redirect_to edit_shop_admin_clipart_set_path(@clipart_set)
  end

  def new
    @clipart_set = ClipartSet.new
  end

  def create
    @clipart_set = ClipartSet.new(clipart_set_params)

    if @clipart_set.save
      @clipart_set.add_pictures(uploaded_pictures)
      redirect_to edit_shop_admin_clipart_set_path(@clipart_set), notice: t(".notice", name: @clipart_set.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @clipart_set.update(clipart_set_params)
      redirect_to edit_shop_admin_clipart_set_path(@clipart_set), notice: t(".notice", name: @clipart_set.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Products that offered it stop offering any pictures until another set or their own is picked.
  def destroy
    @clipart_set.destroy! # its pictures go too
    redirect_to shop_admin_clipart_sets_path, notice: t(".notice", name: @clipart_set.name), status: :see_other
  end

  private
    def set_clipart_set
      @clipart_set = ClipartSet.find(params[:id])
    end

    def clipart_set_params
      params.expect(clipart_set: [ :name ])
    end

    MAX_PICTURE_SIZE = 20.megabytes

    def uploaded_pictures
      Array(params.dig(:clipart_set, :pictures)).select { |file| file.respond_to?(:size) && file.size <= MAX_PICTURE_SIZE }
    end
end
