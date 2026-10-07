require "test_helper"

class Projects::RestorationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "restoring a version runs in the background" do
    assert_enqueued_with(job: RestoreJob, args: [ projects(:clinic), "abc1234" ]) do
      post project_restorations_path(projects(:clinic)), params: { sha: "abc1234" }
    end

    assert projects(:clinic).reload.working?
  end

  test "not while the agent is working" do
    assert_no_enqueued_jobs do
      post project_restorations_path(projects(:shop)), params: { sha: "abc1234" }
    end
  end
end
