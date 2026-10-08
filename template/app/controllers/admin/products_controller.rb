class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @status = Product.statuses.key?(params[:status]) ? params[:status] : nil
    scope = Product.search(params[:q]).ordered.with_attached_images.includes(:variants)
    scope = scope.where(status: @status) if @status
    @page = paginate(scope, per: 50)
  end

  def show
    redirect_to edit_admin_product_path(@product)
  end

  def new
    @product = Product.new(status: "active")
  end

  def create
    @product = Product.new(product_params)
    @product.images.attach(uploaded_images)

    if @product.save
      redirect_to edit_admin_product_path(@product), notice: t(".notice", title: @product.title)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  # New photos are added to the ones the product has; each is removed on its own (ImagesController).
  def update
    if @product.update(product_params)
      @product.images.attach(uploaded_images) if uploaded_images.any?
      redirect_to edit_admin_product_path(@product), notice: t(".notice", title: @product.title)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Products that were ordered keep their orders (line items keep titles and prices).
  def destroy
    @product.destroy!
    redirect_to admin_products_path, notice: t(".notice", title: @product.title), status: :see_other
  end

  private
    def set_product
      @product = Product.find_by!(slug: params[:id])
    end

    def product_params
      params.expect(product: [
        :title, :slug, :description, :status, :base_price,
        :option1_name, :option1_values_text, :option2_name, :option2_values_text, :option3_name, :option3_values_text,
        collection_ids: [],
        variants_attributes: [ [ :id, :price, :compare_at_price, :sku, :available, :cost, :track_inventory, :inventory_quantity ] ]
      ])
    end

    MAX_IMAGE_SIZE = 20.megabytes

    # Photos from the form: images only, up to 20 MB each.
    def uploaded_images
      @uploaded_images ||= Array(params.dig(:product, :images)).select do |file|
        file.respond_to?(:content_type) && file.content_type.to_s.start_with?("image/") && file.size <= MAX_IMAGE_SIZE
      end
    end
end
