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

  test "a live publish applies the storefront's theme settings to its shop" do
    with_projects_root do
      project = projects(:shop)
      project.update!(shop: shops(:cats))
      project.path.join("config").mkpath
      project.path.join("config/theme_settings.yml").write("- key: hero_title\n  type: text\n  default: Cats\n")
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
    end
  end
end
