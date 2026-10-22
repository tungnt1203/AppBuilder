require "test_helper"

# A project (a storefront made from storefront/): its shop, the keys and addresses its storefront
# runs with, and what its agent asks the Platform for.
class ProjectStorefrontTest < ActiveSupport::TestCase
  setup do
    @project = projects(:shop)
    @originals = Rails.configuration.x.platform_url, Rails.configuration.x.platform_url_from_containers
    Rails.configuration.x.platform_url = "http://localhost:3000"
    Rails.configuration.x.platform_url_from_containers = "http://host.docker.internal:3000"
  end

  teardown do
    Rails.configuration.x.platform_url, Rails.configuration.x.platform_url_from_containers = @originals
  end

  test "a storefront opens its own shop once, for the owner, at the project's address" do
    with_projects_root do
      shop = @project.ensure_shop!
      assert_equal [ "Shop", "shop", "owner" ], [ shop.name, shop.subdomain, shop.role_of(users(:owner)) ]
      assert_equal "shop", @project.reload.subdomain
      assert_equal shop, @project.ensure_shop!
    end
  end

  test "a shop's subdomain someone has gets a suffix" do
    with_projects_root do
      @project.update!(name: "Chubby Cat Tees", subdomain: "chubby-cats")
      shop = @project.ensure_shop!
      assert_match(/\Achubby-cats-\h{4}\z/, shop.subdomain)
      assert_equal shop.subdomain, @project.reload.subdomain
    end
  end

  test "the preview runs with the shop's preview key, the published storefront with a live one" do
    with_projects_root do
      @project.ensure_shop!

      preview = @project.storefront_env("preview")
      assert_equal [ "http://localhost:3000", "preview" ], preview.values_at("PLATFORM_URL", "STOREFRONT_MODE") # the local sandbox
      key = ShopApiKey.authenticate(preview["SHOP_KEY"])
      assert key.preview?
      assert_equal @project.shop, key.shop
      assert_equal preview["SHOP_KEY"], @project.storefront_env("preview")["SHOP_KEY"] # made once

      live = @project.storefront_env("live")
      assert_equal "http://host.docker.internal:3000", live["PLATFORM_URL"] # ONCE runs it in a container
      assert_not ShopApiKey.authenticate(live["SHOP_KEY"]).preview?
      assert_not_includes @project.reload.attributes_before_type_cast["live_shop_key"].to_s, live["SHOP_KEY"] # kept encrypted
    end
  end

  test "a project without a shop yet runs with nothing of the Platform's" do
    assert_equal({}, @project.storefront_env("preview"))
  end

  test "what the agent asked the Platform for is filed for the shop, once per request" do
    with_projects_root do
      shop = @project.ensure_shop!
      folder = @project.path.join("tmp/platform_requests").tap(&:mkpath)
      folder.join("1.txt").write("Products need a material field")
      folder.join("2.txt").write("Products need a material field")
      folder.join("3.txt").write("  ")

      requests = @project.take_platform_requests
      assert_equal 2, requests.size
      assert_empty folder.children
      ActsAsTenant.with_tenant(shop) do
        request = PlatformRequest.sole
        assert_equal [ "Products need a material field", 2, "open", @project ], [ request.body, request.times_asked, request.status, request.project ]
      end
    end
  end

  test "deleting a project leaves what its agent asked for in the shop's admin" do
    shop = @project.ensure_shop!
    request = ActsAsTenant.with_tenant(shop) { PlatformRequest.create!(body: "Products need a material field", project: @project) }

    @project.destroy!
    assert_nil request.reload.project_id
  end
end
