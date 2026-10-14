require "test_helper"

class Projects::UpdatesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "the studio offers a newer shop core with what changed, and updating starts it" do
    project = projects(:clinic)
    with_built_apps do
      with_updates({ "shop" => [ "Fix checkout", "Let buyers review" ] }) do
        get project_path(project)
        assert_select "#app-update", /Update ready: shop core \(2 changes\)/
        assert_select "#app-update li", 2
      end
    end

    with_updates({ "shop" => [ "Fix checkout" ] }) do
      assert_enqueued_with(job: ProjectUpdateJob, args: [ project ]) { post project_update_path(project) }
    end
    assert_redirected_to project_path(project)
    assert project.reload.working?
  end

  test "new template features are offered with the shop core" do
    with_built_apps do
      with_updates({ "shop" => [ "Fix checkout" ] }, template: [ "Let buyers review" ]) do
        get project_path(projects(:clinic))
        assert_select "#app-update", /Update ready: shop core and new features \(2 changes\)/
      end
    end
  end

  test "nothing is offered when the app is up to date, or while it's busy" do
    with_built_apps do
      with_updates({}) do
        get project_path(projects(:clinic))
        assert_select "#app-update", 0
      end
      with_updates({ "shop" => [] }) do
        get project_path(projects(:shop))
        assert_select "#app-update", 0
        assert_no_enqueued_jobs { post project_update_path(projects(:shop)) }
      end
    end
  end

  private
    def with_updates(updates, template: [])
      original, files, changes = ProjectBlocks.instance_method(:updates), ProjectTemplate.instance_method(:files), ProjectTemplate.instance_method(:changes)
      ProjectBlocks.define_method(:updates) { updates }
      ProjectTemplate.define_method(:files) { template.map { |change| [ "M", change ] } }
      ProjectTemplate.define_method(:changes) { template }
      yield
    ensure
      ProjectBlocks.define_method(:updates, original)
      ProjectTemplate.define_method(:files, files)
      ProjectTemplate.define_method(:changes, changes)
    end
end
