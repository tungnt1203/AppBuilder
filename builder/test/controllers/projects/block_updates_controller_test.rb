require "test_helper"

class Projects::BlockUpdatesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "the studio offers a newer shop core with what changed, and updating starts it" do
    project = projects(:clinic)
    with_built_apps do
      with_updates("shop" => [ "Fix checkout", "Let buyers review" ]) do
        get project_path(project)
        assert_select "#block-update", /A newer shop core is ready \(2 changes\)/
        assert_select "#block-update li", 2
      end
    end

    with_updates("shop" => [ "Fix checkout" ]) do
      assert_enqueued_with(job: BlockUpdateJob, args: [ project ]) { post project_block_update_path(project) }
    end
    assert_redirected_to project_path(project)
    assert project.reload.working?
  end

  test "nothing is offered when the app is up to date, or while it's busy" do
    with_built_apps do
      with_updates({}) do
        get project_path(projects(:clinic))
        assert_select "#block-update", 0
      end
      with_updates("shop" => []) do
        get project_path(projects(:shop))
        assert_select "#block-update", 0
        assert_no_enqueued_jobs { post project_block_update_path(projects(:shop)) }
      end
    end
  end

  private
    def with_updates(updates)
      original = ProjectBlocks.instance_method(:updates)
      ProjectBlocks.define_method(:updates) { updates }
      yield
    ensure
      ProjectBlocks.define_method(:updates, original)
    end
end
