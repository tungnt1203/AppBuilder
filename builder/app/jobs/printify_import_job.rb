# Imports Printify products into one of the owner's apps (`bin/rails shop:printify_import`, as
# drafts): its published copy when it has one, else its preview. What it brought in is kept on
# the project for /admin/products to show.
class PrintifyImportJob < ApplicationJob
  MARKER = "PRINTIFY_IMPORT_RESULT"

  def perform(project, ids)
    copy = project.deployments.live.exists? ? :live : :preview
    result = AppTask.new(project).run("shop:printify_import", marker: MARKER, copy:, input: { ids: }.to_json)
    project.update!(printify_import_result: result.merge("copy" => copy.to_s), printify_imported_at: Time.current)
    OrdersRefreshJob.perform_later(project)
  end
end
