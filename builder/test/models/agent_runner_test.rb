require "test_helper"

class AgentRunnerTest < ActiveSupport::TestCase
  test "cli backend continues the project's session" do
    command = AgentRunner.new(projects(:clinic), backend: "cli").command("Thêm trang báo cáo")

    assert_equal [ "claude", "-p", "Thêm trang báo cáo" ], command.first(3)
    assert_includes command, "stream-json"
    assert_equal [ "--resume", "session-123" ], command.last(2)
    assert_includes command, "Bash(bin/rails:*)"
  end

  test "plan mode proposes without changing anything" do
    assert_includes AgentRunner.new(projects(:clinic), mode: "plan", backend: "cli").command("Hi"), "plan"
    assert_includes AgentRunner.new(projects(:clinic), mode: "build", backend: "cli").command("Hi"), "acceptEdits"
  end

  test "first turn starts a new session" do
    assert_not_includes AgentRunner.new(projects(:shop), backend: "cli").command("Hi"), "--resume"
  end

  test "sdk backend runs the node runner with a config file" do
    command = AgentRunner.new(projects(:clinic), backend: "sdk").command("Hi", "/tmp/agent.json")

    assert_equal [ "node", Rails.root.join("runner/index.mjs").to_s ], command.first(2)
    assert_includes command, "/tmp/agent.json"
  end

  test "only the agent gets the stock photo keys" do
    keys = Rails.configuration.x.stock_photo_keys
    Rails.configuration.x.stock_photo_keys = { "PEXELS_API_KEY" => "pexels-key" }

    assert_equal "pexels-key", AgentRunner.new(projects(:clinic)).environment["PEXELS_API_KEY"]
    assert_includes ProjectShell::SECRETS, "PEXELS_API_KEY"
  ensure
    Rails.configuration.x.stock_photo_keys = keys
  end

  test "claude doesn't inherit the Claude Code session the builder was started from" do
    ENV["CLAUDE_CODE_SESSION_ID"] = "parent-session"

    environment = AgentRunner.new(projects(:clinic)).environment
    assert environment.key?("CLAUDE_CODE_SESSION_ID")
    assert_nil environment["CLAUDE_CODE_SESSION_ID"]
  ensure
    ENV.delete("CLAUDE_CODE_SESSION_ID")
  end

  test "unknown backends are rejected" do
    assert_raises(ArgumentError) { AgentRunner.new(projects(:clinic), backend: "nope").command("Hi") }
  end
end
