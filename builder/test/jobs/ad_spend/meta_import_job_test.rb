require "test_helper"

class AdSpend::MetaImportJobTest < ActiveJob::TestCase
  setup do
    in_shop
    @meta = connect_fake_meta
    Store.current.update!(meta_ad_account_id: "act_998877665544")
  end

  test "brings in the ad account's spend for the last week's days as facebook, replacing what was typed" do
    today = Time.current.to_date
    AdSpend.create!(date: today - 1, source: "facebook", amount_cents: 100)
    @meta.spend = { today - 1 => "42.50", today - 3 => "10", today - 20 => "99" }

    AdSpend::MetaImportJob.perform_now

    assert_equal [ { account_id: "998877665544", since: today - 6, till: today } ], @meta.asked
    assert_equal({ today - 1 => 4250, today - 3 => 1000 }, AdSpend.where(source: "facebook").pluck(:date, :amount_cents).to_h)
    assert Store.current.reload.meta_ad_spend_synced_at
  end

  test "an account in another currency, or a token that can't read it, is shown to the owner instead" do
    @meta.currency = "VND"
    @meta.spend = { Time.current.to_date => "250000" }
    AdSpend::MetaImportJob.perform_now
    assert_empty AdSpend.all
    assert_match(/in VND and the shop in USD/, Store.current.reload.meta_ad_spend_error)

    @meta.error = MetaGateway::Refused.new("Meta didn't let the access token read the ad account's spend (no). It needs the ads_read permission on that ad account.")
    AdSpend::MetaImportJob.perform_now
    assert_match(/ads_read/, Store.current.reload.meta_ad_spend_error)
  end
end
