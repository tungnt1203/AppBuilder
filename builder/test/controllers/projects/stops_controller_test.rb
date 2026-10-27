require "test_helper"

class Projects::StopsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "stopping a working agent" do
    project = projects(:shop)
    project.update!(working_since: 1.minute.ago, turn_heartbeat_at: 5.seconds.ago)

    with_agent_backend("sdk") { post project_stop_path(project) }

    assert project.agent_commands.interrupt.pending.exists?
    assert project.stop_requested?
    assert project.reload.working?
    assert_equal "Stopped. What's done so far is kept.", project.messages.last.body
  end

  test "an app left working with nothing running is ready again" do
    project = projects(:shop)
    project.update!(working_since: 10.minutes.ago, turn_heartbeat_at: nil, activity: "Starting")

    with_agent_backend("sdk") { post project_stop_path(project) }

    assert project.reload.ready?
    assert_nil project.activity
    assert_match "Nothing was running", project.messages.last.body
  end

  test "an app stuck after an earlier Stop can still be stopped" do
    project = projects(:shop)
    project.update!(working_since: 10.minutes.ago, turn_heartbeat_at: nil)
    project.agent_commands.create!(kind: :interrupt)

    with_agent_backend("sdk") { post project_stop_path(project) }

    assert project.reload.ready?
  end

  test "moving or updating the app isn't something Stop cuts short" do
    project = projects(:shop)
    project.update!(activity: "Moving to new-name.localhost", turn_heartbeat_at: nil)

    with_agent_backend("sdk") { post project_stop_path(project) }

    assert project.reload.working?
    assert_empty project.agent_commands
  end

  test "nothing to stop when idle" do
    post project_stop_path(projects(:clinic))

    assert_empty projects(:clinic).agent_commands
  end
end
