require "test_helper"

class Projects::WorkerChecksControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "says so when no worker picks up the background jobs" do
    with_job_worker(false) { get project_worker_check_path(projects(:shop)) }
    assert_select "turbo-frame#worker-check p[role=alert]", /Background jobs aren't running/

    with_job_worker(true) { get project_worker_check_path(projects(:shop)) }
    assert_select "turbo-frame#worker-check"
    assert_select "p[role=alert]", count: 0
  end
end
