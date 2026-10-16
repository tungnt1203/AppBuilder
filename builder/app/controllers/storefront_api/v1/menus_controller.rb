# One of the shop's menus (header, footer): labels and where they go.
class StorefrontApi::V1::MenusController < StorefrontApi::V1::BaseController
  def show
    render json: { menu: json.menu(Menu.find_by!(key: params[:id])) }
  end
end
