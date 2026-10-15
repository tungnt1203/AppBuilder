require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as users(:owner) }

  test "shows the last 30 days and the latest orders of all the owner's shops" do
    shop = users(:owner).projects.listed.first
    shop.update!(orders_summary_source: "preview", orders_summary_at: 5.minutes.ago, orders_summary: {
      "currency" => "USD", "sales_cents" => 5400, "orders" => 2, "needs_action" => 1, "problems" => 1, "margin_cents" => 1900,
      "recent" => [ { "number" => 1002, "token" => "tok2", "name" => "Robin Buyer", "status" => "paid", "total_cents" => 2900,
        "currency" => "USD", "margin_cents" => 1200, "problem" => "Address is invalid", "placed_at" => 1.hour.ago.iso8601 } ] })

    get admin_root_path
    assert_select "h1", "Orders"
    assert_select "li", /Sales\s*\$54.00/
    assert_select "li", /Need you\s*2/
    assert_select "a[href=?]", project_path(shop), /#1002 · Robin Buyer/
    assert_select "p", "Address is invalid"
    assert_select "aside[aria-label=Admin] a", "Accounts" # an administrator of the builder
  end

  test "a member's admin has their orders and settings, not the accounts" do
    sign_in_as users(:member)
    get admin_root_path
    assert_select "aside[aria-label=Admin] a", text: "Accounts", count: 0
    get admin_users_path
    assert_response :not_found
  end

  test "Refresh asks each selling shop again" do
    with_selling(users(:owner).projects.listed.first) do
      assert_enqueued_jobs 1, only: OrdersRefreshJob do
        post admin_orders_refresh_path
      end
    end
    assert_redirected_to admin_root_path
  end

  test "a published shop's orders open in its own admin" do
    project = projects(:clinic)
    project.update!(orders_summary_source: "live")
    assert_equal "#{project.publish_url}/admin/orders/tok", ShopOrders.order_url(project, "tok")
  end

  private
    def with_selling(project)
      root = Pathname(Dir.mktmpdir)
      original, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, root
      project.path.join("config").mkpath
      project.path.join("config/application.rb").write("config.x.shop = true\n")
      project.update!(status: :ready)
      yield
    ensure
      Rails.configuration.x.projects_root = original
      FileUtils.rm_rf(root)
    end
end
