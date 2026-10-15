require "test_helper"

class PrintifyImportJobTest < ActiveJob::TestCase
  test "imports into the shop as drafts and keeps what came in" do
    in_shop(shops(:cats))
    connect_fake_printify
    ActsAsTenant.current_tenant = nil

    PrintifyImportJob.perform_now(shops(:cats), [ "pf-tee" ])

    result = shops(:cats).reload.printify_import_result
    assert_equal [ "Sunset Tee", "draft" ], result.dig("imported", 0).values_at("title", "status")
    assert_empty result["errors"]
    in_shop(shops(:cats))
    assert Product.exists?(printify_product_id: "pf-tee")
  end

  test "a shop without Printify is told to connect it" do
    PrintifyImportJob.perform_now(shops(:dogs), [ "pf-tee" ])
    assert_match "isn't connected", shops(:dogs).reload.printify_import_result["errors"].sole
  end
end
