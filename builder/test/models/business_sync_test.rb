require "test_helper"

class BusinessSyncTest < ActiveSupport::TestCase
  setup do
    @project = projects(:clinic)
    @setting = @project.owner.create_business_setting!(stripe_secret_key: "sk_test_abc", meta_pixel_id: "123456789012")
  end

  test "secrets are encrypted, shown masked, and every key goes to the app, blank when unset" do
    raw = BusinessSetting.connection.select_value("SELECT stripe_secret_key FROM business_settings WHERE id = #{@setting.id}")
    assert_not_includes raw, "sk_test_abc"
    assert_equal "sk_test_…_abc", BusinessSetting.masked("sk_test_abc")
    assert_equal({ "stripe_secret_key" => "sk_test_abc", "printify_token" => "", "printify_shop_id" => "", "meta_pixel_id" => "123456789012",
      "meta_access_token" => "", "tiktok_pixel_id" => "", "google_tag_id" => "" }, @setting.payload)
  end

  test "applies the settings to the app's preview through a variable and keeps what it answered" do
    calls = []
    with_project_files(@project) do
      answer_with(@project, "Loading...\nBUSINESS_SETTINGS_RESULT {\"stripe\":\"Acme (test mode)\",\"errors\":[]}\n", true) { |call| calls << call }
      BusinessSync.new(@project).call
    end

    command, env = calls.sole
    assert_equal [ "bin/rails", "shop:business_settings" ], command
    assert_equal "sk_test_abc", JSON.parse(env["BUSINESS_SETTINGS"])["stripe_secret_key"]
    assert_equal({ "preview" => { "stripe" => "Acme (test mode)", "errors" => [] } }, @project.reload.business_sync_result)
    assert @project.business_synced_at
  end

  test "an app whose core can't take them yet is told to update" do
    with_project_files(@project) do
      answer_with(@project, "rails aborted!\nDon't know how to build task 'shop:business_settings'", false)
      BusinessSync.new(@project).call
    end
    assert_match "Update the app first", @project.reload.business_sync_result.dig("preview", "errors", 0)
  end

  test "apps that sell nothing are left alone" do
    with_project_files(@project, application: "config.x.shop = false\n") do
      assert_not BusinessSync.new(@project).applicable?
    end
  end

  private
    # The app's sandbox answering what's given, recording each command it's asked to run.
    def answer_with(project, output, succeeded, &record)
      sandbox = Object.new
      sandbox.define_singleton_method(:capture) do |*command, env: {}|
        record&.call([ command, env ])
        [ output, succeeded ]
      end
      project.define_singleton_method(:sandbox) { sandbox }
    end

    def with_project_files(project, application: "config.x.shop = true\n")
      root = Pathname(Dir.mktmpdir)
      original, Rails.configuration.x.projects_root = Rails.configuration.x.projects_root, root
      project.path.join("config").mkpath
      project.path.join("config/application.rb").write(application)
      project.update!(status: :ready)
      yield
    ensure
      Rails.configuration.x.projects_root = original
      FileUtils.rm_rf(root)
    end
end
