require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:owner)
    @shop = users(:owner).projects.listed.first
    @root = Pathname(Dir.mktmpdir)
    @original_root, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, @root
    @shop.path.join("config").mkpath
    @shop.path.join("config/application.rb").write("config.x.shop = true\n")
    @shop.update!(status: :ready)
    products = [ { "id" => "pf-1", "title" => "Cat Tee", "image" => "https://images.example/cat.jpg", "price_cents" => 2500, "cost_cents" => 1150 } ]
    PrintifyAccount.singleton_class.alias_method(:original_products, :products)
    PrintifyAccount.define_singleton_method(:products) { |_token, _shop, page: 1| [ products, 1 ] }
  end

  teardown do
    PrintifyAccount.singleton_class.alias_method(:products, :original_products)
    Rails.configuration.x.projects_root = @original_root
    FileUtils.rm_rf(@root)
  end

  test "asks to connect Printify first" do
    get admin_products_path
    assert_select "p", /Connect Printify in Settings first/
  end

  test "lists the Printify products with their margins and imports the picked ones into a shop" do
    users(:owner).create_business_setting!(printify_token: "pf-token", printify_shop_id: "11", printify_shop_title: "Cat shop")

    get admin_products_path
    assert_select "label", /Cat Tee.*From \$25.00 · costs \$11.50.*54% margin/m
    assert_select "select[name=project_id] option", text: @shop.name

    assert_enqueued_with(job: PrintifyImportJob, args: [ @shop, [ "pf-1" ] ]) do
      post admin_products_path, params: { project_id: @shop.id, product_ids: [ "pf-1" ] }
    end
    assert_redirected_to admin_products_path(page: nil)
  end

  test "only the owner's own apps can be imported into" do
    other = projects(:clinic).dup.tap { |copy| copy.assign_attributes(owner: users(:member), slug: "other-app", port: 4999, subdomain: nil, share_token: nil); copy.save!(validate: false) }
    post admin_products_path, params: { project_id: other.id, product_ids: [ "pf-1" ] }
    assert_response :not_found
  end
end
