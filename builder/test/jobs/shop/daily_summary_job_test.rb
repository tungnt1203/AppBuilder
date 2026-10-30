require "test_helper"

class Shop::DailySummaryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    shops(:cats).update!(time_zone: "Asia/Ho_Chi_Minh")
    @morning = Time.find_zone("Asia/Ho_Chi_Minh").local(2026, 10, 30, 8, 10)
    ActsAsTenant.with_tenant(shops(:cats)) do
      orders(:paid).update_columns(created_at: @morning - 1.day, tax_cents: 0)
      AdSpend.create!(date: Date.new(2026, 10, 29), source: "tiktok", amount_cents: 500)
    end
  end

  test "at 8 in the shop's morning, its owners and admins get yesterday, when something happened" do
    travel_to @morning do
      assert_enqueued_emails 1 do
        Shop::DailySummaryJob.perform_now(now: @morning)
      end
      assert_no_enqueued_emails { Shop::DailySummaryJob.perform_now(now: @morning + 1.hour) }
    end

    mail = travel_to(@morning) { Admin::SummaryMailer.daily(shops(:cats), "2026-10-29") }
    assert_equal "Chubby Cat Tees yesterday: 1 order, $20.00", mail.subject
    assert_equal shops(:cats).memberships.where(role: %w[ owner admin ]).joins(:user).pluck("users.email_address").sort, mail.to.sort
    text = mail.text_part.body.to_s
    assert_includes text, "Sales: $20.00"
    assert_includes text, "Ad spend: $5.00, 4.00× back"
    assert_includes text, "Morning Mug: 1 sold, $15.00"
    assert_includes text, "1 order is waiting to ship."
  end

  test "a quiet day sends nothing" do
    ActsAsTenant.with_tenant(shops(:cats)) { orders(:paid).update_columns(created_at: @morning - 5.days) }
    travel_to(@morning) { assert_no_enqueued_emails { Shop::DailySummaryJob.perform_now(now: @morning) } }
  end
end
