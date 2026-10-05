require "test_helper"

class AgentRunnerTest < ActiveSupport::TestCase
  test "cli backend continues the project's session" do
    command = AgentRunner.new(projects(:clinic), backend: "cli").command("Thêm trang báo cáo")

    assert_equal [ "claude", "-p", "Thêm trang báo cáo" ], command.first(3)
    assert_includes command, "stream-json"
    assert_equal [ "--resume", "session-123" ], command.last(2)
    assert_includes command, "Bash(bin/rails:*)"
  end

  test "first turn starts a new session" do
    assert_not_includes AgentRunner.new(projects(:shop), backend: "cli").command("Hi"), "--resume"
  end

  test "sdk backend runs the node runner with a config file" do
    command = AgentRunner.new(projects(:clinic), backend: "sdk").command("Hi", "/tmp/agent.json")

    assert_equal [ "node", Rails.root.join("runner/index.mjs").to_s ], command.first(2)
    assert_includes command, "/tmp/agent.json"
  end

  test "unknown backends are rejected" do
    assert_raises(ArgumentError) { AgentRunner.new(projects(:clinic), backend: "nope").command("Hi") }
  end
end
