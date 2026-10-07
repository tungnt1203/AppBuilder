require "test_helper"

class AppLimitTest < ActiveSupport::TestCase
  setup { @member = users(:member) }

  test "a member's account holds a limited number of apps" do
    with_app_limit(2) do
      2.times { |i| Project.create!(name: "App #{i}", language: "vi", owner: @member) }
      assert @member.app_limit_reached?

      third = Project.new(name: "App 3", language: "vi", owner: @member)
      assert_not third.valid?
      assert_includes third.errors.full_messages.to_sentence, "You can have 2 apps"
    end
  end

  test "deleting an app makes room" do
    with_app_limit(1) do
      app = Project.create!(name: "App", language: "vi", owner: @member)
      assert @member.app_limit_reached?

      app.destroy!
      assert_not @member.app_limit_reached?
    end
  end

  test "administrators have no limit" do
    with_app_limit(1) do
      assert_nil users(:owner).app_limit
      assert_operator users(:owner).projects.count, :>, 1
      assert Project.new(name: "Another", language: "vi", owner: users(:owner)).valid?
    end
  end

  test "a copy belongs to whoever made it and counts against their apps" do
    with_app_limit(1) do
      copy = projects(:clinic).duplicate(owner: @member)
      assert_equal @member, copy.owner

      assert_raises(ActiveRecord::RecordInvalid) { projects(:clinic).duplicate(owner: @member) }
    end
  end

  private
    def with_app_limit(limit)
      original, Rails.configuration.x.apps_per_account = Rails.configuration.x.apps_per_account, limit
      yield
    ensure
      Rails.configuration.x.apps_per_account = original
    end
end
