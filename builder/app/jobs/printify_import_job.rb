# Imports Printify products into one of the owner's shops as drafts (Printify::Import), for them
# to check before they go on sale. What it brought in is kept on the shop for /admin/products.
class PrintifyImportJob < ApplicationJob
  def perform(shop, ids)
    result = ActsAsTenant.with_tenant(shop) { import(ids) }
    shop.update!(printify_import_result: result, printify_imported_at: Time.current)
  end

  private
    def import(ids)
      result = { "imported" => [], "errors" => [] }
      return result.merge("errors" => [ "Printify isn't connected in this shop: connect it in its settings first" ]) unless Store.current.printify_connected?

      ids.each do |id|
        product = Printify::Import.new.call(id)
        result["imported"] << { "id" => id, "title" => product.title, "status" => product.status, "to_check" => product.launch_problems }
      rescue PrintifyGateway::Error, ActiveRecord::RecordInvalid => error
        result["errors"] << "#{id}: #{error.message}"
      end
      result
    end
end
