# A sample print file of a personalized product (Personalization::PrintFile.sample), for the owner
# to see that what buyers add lands where it should on Printify's print area. Its shape is the print
# area's as drawn on the photo; the real one has Printify's size.
class ShopAdmin::Products::PrintFilesController < ShopAdmin::BaseController
  WIDTH = 1200

  def show
    product = Product.find_by!(slug: params[:product_id])
    file = Personalization::PrintFile.sample(product)
    return head :not_found unless file.printable?

    send_data file.render(width: WIDTH, height: (WIDTH / aspect(product)).round), type: "image/png", disposition: "inline"
  rescue Personalization::PrintFile::Error => error
    render plain: error.message, status: :unprocessable_entity
  end

  private
    # The print area's width over its height, as drawn on the product's first photo.
    def aspect(product)
      photo = Vips::Image.new_from_buffer(product.images.first.download, "")
      area = product.print_area
      area["w"] * photo.width / (area["h"] * photo.height)
    end
end
