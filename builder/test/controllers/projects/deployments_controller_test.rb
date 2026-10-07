require "test_helper"

class Projects::DeploymentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "publishing a ready project starts a deployment" do
    with_built_apps do
      assert_enqueued_with(job: PublishJob) do
        post project_deployments_path(projects(:clinic))
      end
    end

    assert projects(:clinic).latest_deployment.building?
    assert_redirected_to project_path(projects(:clinic))
  end

  test "can't publish the starter app before anything is built" do
    with_built_apps(false) do
      assert_no_enqueued_jobs { post project_deployments_path(projects(:clinic)) }

      get project_path(projects(:clinic))
      assert_select "form[action='#{project_deployments_path(projects(:clinic))}'] button[disabled][title='Build the app before publishing']"
    end
  end

  test "can't publish while the agent is working or a publish is running" do
    projects(:clinic).deployments.create!

    assert_no_enqueued_jobs do
      post project_deployments_path(projects(:clinic))
      post project_deployments_path(projects(:shop))
    end
  end
end
