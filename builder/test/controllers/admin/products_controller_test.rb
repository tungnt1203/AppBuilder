require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:member)
    products = [ { "id" => "pf-1", "title" => "Cat Tee", "image" => "https://images.example/cat.jpg", "price_cents" => 2500, "cost_cents" => 1150 } ]
    PrintifyAccount.singleton_class.alias_method(:original_products, :products)
    PrintifyAccount.define_singleton_method(:products) { |_token, _shop, page: 1| [ products, 1 ] }
  end

  teardown do
    PrintifyAccount.singleton_class.alias_method(:products, :original_products)
  end

  test "asks to connect Printify first" do
    get admin_products_path
    assert_select "p", /Connect Printify in Settings first/
  end

  test "lists the Printify products with their margins and imports the picked ones into a shop" do
    users(:member).create_business_setting!(printify_token: "pf-token", printify_shop_id: "11", printify_shop_title: "Cat shop")
    shops(:cats).update!(printify_imported_at: 1.hour.ago, printify_import_result: { "imported" => [ { "title" => "Old Tee", "status" => "draft", "to_check" => [ "no_size_guide" ] } ], "errors" => [] })

    get admin_products_path
    assert_select "label", /Cat Tee.*From \$25.00, costs \$11.50.*\(54% margin\)/m
    assert_select "select[name=shop_id] option", 2
    assert_select "p", /Old Tee: draft, to check: No size guide/

    assert_enqueued_with(job: PrintifyImportJob, args: [ shops(:cats), [ "pf-1" ] ]) do
      post admin_products_path, params: { shop_id: "chubby-cats", product_ids: [ "pf-1" ] }
    end
    assert_redirected_to admin_products_path(page: nil)
  end

  test "only the shops someone runs can be imported into" do
    sign_in_as users(:cats_staff)
    post admin_products_path, params: { shop_id: "good-boy", product_ids: [ "pf-1" ] }
    assert_response :not_found
  end
end
