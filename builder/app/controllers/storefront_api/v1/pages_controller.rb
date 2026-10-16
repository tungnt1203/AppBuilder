# A published page (about, FAQ) as blocks of text and questions.
class StorefrontApi::V1::PagesController < StorefrontApi::V1::BaseController
  def show
    render json: { page: json.page(Page.published.find_by!(slug: params[:id])) }
  end
end
