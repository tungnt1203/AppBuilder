# Several products at once, ticked in the list: put on sale, back to draft, archived or deleted;
# all of them or, when one can't be, none.
class ShopAdmin::ProductBatchesController < ShopAdmin::BaseController
  ACTIONS = %w[ active draft archived delete ].freeze

  def update
    products = Product.where(slug: Array(params[:product_slugs]))
    action = params[:batch_action].presence_in(ACTIONS)
    return redirect_back_or_to(shop_admin_products_path, alert: t(".nothing")) if products.none? || action.nil?

    count = products.count
    Product.transaction do
      action == "delete" ? products.find_each(&:destroy!) : products.find_each { |product| product.update!(status: action) }
    end
    redirect_back_or_to shop_admin_products_path, notice: t(".#{action}", count:), status: :see_other
  rescue ActiveRecord::RecordInvalid => invalid
    redirect_back_or_to shop_admin_products_path, alert: t(".failed", title: invalid.record.title, problem: invalid.record.errors.full_messages.to_sentence), status: :see_other
  end
end
