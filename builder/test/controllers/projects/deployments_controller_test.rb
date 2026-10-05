require "test_helper"

class Projects::DeploymentsControllerTest < ActionDispatch::IntegrationTest
  test "publishing a ready project starts a deployment" do
    assert_enqueued_with(job: PublishJob) do
      post project_deployments_path(projects(:clinic))
    end

    assert projects(:clinic).latest_deployment.building?
    assert_redirected_to project_path(projects(:clinic))
  end

  test "can't publish while the agent is working or a publish is running" do
    projects(:clinic).deployments.create!

    assert_no_enqueued_jobs do
      post project_deployments_path(projects(:clinic))
      post project_deployments_path(projects(:shop))
    end
  end
end
