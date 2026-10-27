# A set's pictures: added (chosen or dropped, sent at once), renamed (the name buyers see under
# one) and taken out. Products offering the set follow it.
class ShopAdmin::ClipartSets::PicturesController < ShopAdmin::BaseController
  MAX_SIZE = 20.megabytes

  before_action :set_clipart_set
  before_action :set_picture, only: %i[ update destroy ]

  def create
    sent = Array(params[:pictures]).select { |file| file.respond_to?(:size) }
    added = @clipart_set.add_pictures(sent.select { |file| file.size <= MAX_SIZE })
    skipped = sent.size - added
    redirect_to edit_shop_admin_clipart_set_path(@clipart_set, anchor: "pictures"),
      notice: (t(".notice", count: added) if added.positive?), alert: (t(".skipped", count: skipped, most: ClipartSet::MAX_PICTURES) if skipped.positive?)
  end

  def update
    renamed = @clipart_set.rename_picture(@picture, params.dig(:picture, :name))
    redirect_to edit_shop_admin_clipart_set_path(@clipart_set, anchor: "pictures"), alert: (t(".invalid") unless renamed)
  end

  def destroy
    @clipart_set.remove_picture(@picture)
    redirect_to edit_shop_admin_clipart_set_path(@clipart_set, anchor: "pictures"), notice: t(".notice", name: @picture.filename.base), status: :see_other
  end

  private
    def set_clipart_set
      @clipart_set = ClipartSet.find(params[:clipart_set_id])
    end

    def set_picture
      @picture = @clipart_set.pictures.find(params[:id])
    end
end
