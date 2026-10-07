class Admin::CollectionsController < Admin::BaseController
  before_action :set_collection, only: %i[ show edit update destroy ]

  def index
    @collections = Collection.ordered.left_joins(:collection_products).group(:id).select("collections.*, COUNT(collection_products.id) AS products_count")
  end

  def show
    redirect_to edit_admin_collection_path(@collection)
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.new(collection_params)

    if @collection.save
      @collection.arrange_products(params.dig(:collection, :product_ids))
      redirect_to admin_collections_path, notice: t(".notice", title: @collection.title)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @collection.update(collection_params)
      @collection.arrange_products(params.dig(:collection, :product_ids))
      redirect_to admin_collections_path, notice: t(".notice", title: @collection.title)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy!
    redirect_to admin_collections_path, notice: t(".notice", title: @collection.title), status: :see_other
  end

  private
    def set_collection
      @collection = Collection.find_by!(slug: params[:id])
    end

    def collection_params
      params.expect(collection: [ :title, :slug, :description, :position ])
    end
end
