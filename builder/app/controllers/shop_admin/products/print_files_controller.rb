# A sample print file of one side of a personalized product (Personalization::PrintFile.sample), for the owner
# to see that what buyers add lands where it should on Printify's print area. Its shape is the print
# area's as drawn on the photo; the real one has Printify's size.
class ShopAdmin::Products::PrintFilesController < ShopAdmin::BaseController
  WIDTH = 1200

  def show
    product = Product.find_by!(slug: params[:product_id])
    file = Personalization::PrintFile.sample(product, side: params[:side].presence_in(Product::PRINT_POSITIONS) || "front")
    return head :not_found unless file.printable?

    send_data file.render(width: WIDTH, height: (WIDTH / aspect(product, file.area)).round), type: "image/png", disposition: "inline"
  rescue Personalization::PrintFile::Error => error
    render plain: error.message, status: :unprocessable_entity
  end

  private
    # The print area's width over its height, as drawn on the product's first photo (its photos
    # are the same size).
    def aspect(product, area)
      photo = Vips::Image.new_from_buffer(product.images.first.download, "")
      area["w"] * photo.width / (area["h"] * photo.height)
    end
end
