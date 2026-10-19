require "test_helper"

class PublisherTest < ActiveSupport::TestCase
  setup { @project = projects(:clinic) }

  test "first publish builds, pushes and deploys to ONCE" do
    deployment = @project.deployments.create!
    publisher = Publisher.new(deployment, once: "once")

    assert_equal [ "docker", "build", "--tag", "localhost:5050/nha-khoa:v1", "." ], publisher.build_steps.first
    assert_equal [ [ "once", "deploy", "localhost:5050/nha-khoa:v1", "--host", "nha-khoa.localhost", "--auto-update=false" ] ], publisher.deploy_steps
  end

  test "later publishes back up the live version before updating it" do
    @project.deployments.create!(status: :live)
    deployment = @project.deployments.create!

    backup, update = Publisher.new(deployment, once: "once").deploy_steps

    assert_equal [ "once", "backup", "nha-khoa.localhost" ], backup.first(3)
    assert backup.last.end_with?("nha-khoa/before-v2.tar.gz")
    assert_equal [ "once", "update", "nha-khoa.localhost", "--image", "localhost:5050/nha-khoa:v2" ], update
  end

  test "the first publish tells the owner where to create their account" do
    deployment = @project.deployments.create!
    publisher = Publisher.new(deployment, once: "once")
    def publisher.run_steps(*) = nil # no docker or ONCE in tests

    shell = Object.new
    def shell.run(*) = "abc1234\n"
    @project.define_singleton_method(:shell) { shell }

    publisher.publish

    assert deployment.reload.live?
    assert_match "http://nha-khoa.localhost/session/new", @project.messages.last.body
  end

  test "a live publish applies the storefront's theme settings and forms to its shop" do
    with_projects_root do
      project = projects(:shop)
      project.update!(shop: shops(:cats))
      project.path.join("config").mkpath
      project.path.join("config/theme_settings.yml").write("- key: hero_title\n  type: text\n  default: Cats\n")
      project.path.join("config/forms.yml").write(<<~YAML)
        - key: contact
          title: Contact us
          fields:
            - { key: email, label: Email, type: email, required: true }
      YAML
      deployment = project.deployments.create!
      publisher = Publisher.new(deployment, once: "once")
      def publisher.run_steps(*) = nil

      shell = Object.new
      def shell.run(*) = "abc1234\n"
      project.define_singleton_method(:shell) { shell }

      publisher.publish

      setting = ActsAsTenant.with_tenant(shops(:cats)) { ThemeSetting.current }
      assert_equal "Cats", setting.resolved["hero_title"]
      assert_equal "abc1234", setting.schema_version
      form = ActsAsTenant.with_tenant(shops(:cats)) { Form.find_by!(key: "contact") }
      assert_equal [ [ "email", true ] ], form.fields.map { |field| field.values_at("key", "required") }

      project.path.join("config/forms.yml").write("- key: newsletter\n  title: News\n  fields: [ { key: email, label: Email } ]\n- key: broken\n")
      later = project.deployments.create!
      later_publisher = Publisher.new(later, once: "once")
      def later_publisher.run_steps(*) = nil
      later_publisher.publish

      assert later.reload.live?
      assert_match "config/forms.yml not applied", later.log
      assert_equal [ "contact" ], ActsAsTenant.with_tenant(shops(:cats)) { Form.pluck(:key) }
    end
  end

  test "a storefront is published with the Platform's address and its shop's live key, which the log never shows" do
    with_projects_root do
      project = projects(:shop)
      project.path.join("vendor/blocks/storefront_kit").mkpath
      project.ensure_shop!
      deployment = project.deployments.create!
      publisher = Publisher.new(deployment, once: "once")

      flags = publisher.deploy_steps.sole.each_cons(2).filter_map { |flag, value| value if flag == "--env" }
      assert_equal %w[ PLATFORM_URL SHOP_KEY STOREFRONT_MODE ], flags.map { |flag| flag.split("=").first }
      key = flags.find { |flag| flag.start_with?("SHOP_KEY=") }.delete_prefix("SHOP_KEY=")
      assert_equal project.shop, ShopApiKey.authenticate(key).shop

      def publisher.build_steps = []
      shell = Object.new
      def shell.run(*) = "abc1234\n"
      project.define_singleton_method(:shell) { shell }
      publisher.publish

      assert deployment.reload.live?
      assert_includes deployment.log, "SHOP_KEY=[hidden]"
      assert_not_includes deployment.log, key
      assert_equal "live", project.shop.reload.status
      assert_match "in the shop's admin", project.messages.last.body
    end
  end
end
