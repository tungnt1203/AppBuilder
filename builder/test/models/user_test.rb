require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "members spend up to the monthly budget; earlier months and administrators don't count" do
    member = users(:member)
    member.usages.create!(cost_usd: 19.9)
    member.usages.create!(cost_usd: 50, created_at: 1.month.ago.beginning_of_month)

    assert_in_delta 19.9, member.spent_this_month
    assert_in_delta 0.1, member.budget_left
    assert member.over_budget?
    assert_match "$19.90 of $20.00", member.budget_message

    users(:owner).usages.create!(cost_usd: 500)
    assert_nil users(:owner).budget_left
    assert_not users(:owner).over_budget?
  end
end
