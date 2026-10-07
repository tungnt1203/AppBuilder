require "test_helper"

class Projects::StopsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "stopping a working agent" do
    project = projects(:shop)
    project.update!(working_since: 1.minute.ago)

    with_agent_backend("sdk") { post project_stop_path(project) }

    assert project.agent_commands.interrupt.pending.exists?
    assert project.stop_requested?
    assert_equal "notice", project.messages.last.role
  end

  test "nothing to stop when idle" do
    post project_stop_path(projects(:clinic))

    assert_empty projects(:clinic).agent_commands
  end
end
