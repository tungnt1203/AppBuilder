# The people who bought (Buyer): who they are, how often they order and what they spent, with
# their orders; and the list as a spreadsheet for an email tool or an ad audience.
class ShopAdmin::CustomersController < ShopAdmin::BaseController
  def index
    @sort = Buyer::SORTS.key?(params[:sort]) ? params[:sort] : "recent"
    buyers = Buyer.all(query: params[:q], sort: @sort)

    respond_to do |format|
      format.html { @page = paginate(buyers, per: 50) }
      format.csv do
        send_data Spreadsheet.customers(buyers, currency: Store.current.currency),
          filename: "#{current_shop.subdomain}-customers-#{Date.current}.csv", type: "text/csv"
      end
    end
  end

  def show
    @buyer = Buyer.find(params[:id])
    @orders = Buyer.orders.where(email: @buyer.email).newest_first
  end
end
