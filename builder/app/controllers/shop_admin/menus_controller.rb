class ShopAdmin::MenusController < ShopAdmin::BaseController
  before_action :require_administrator
  before_action :set_menu, only: %i[ edit update destroy ]

  def index
    @menus = Menu.order(:title)
  end

  def new
    @menu = Menu.new
  end

  def create
    @menu = Menu.new(menu_params)
    if @menu.save
      redirect_to shop_admin_menus_path, notice: t(".notice", title: @menu.title)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @menu.update(menu_params)
      redirect_to shop_admin_menus_path, notice: t(".notice", title: @menu.title)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu.destroy!
    redirect_to shop_admin_menus_path, notice: t(".notice", title: @menu.title), status: :see_other
  end

  private
    def set_menu
      @menu = Menu.find_by!(key: params[:id])
    end

    def menu_params
      params.expect(menu: [ :key, :title, items: [ [ :label, :url ] ] ])
    end
end
