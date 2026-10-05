require "test_helper"

class ProjectShellTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir)
    @original = ENV["CLAUDE_CODE_OAUTH_TOKEN"]
    ENV["CLAUDE_CODE_OAUTH_TOKEN"] = "sk-ant-oat01-secret"
  end

  teardown do
    ENV["CLAUDE_CODE_OAUTH_TOKEN"] = @original
    FileUtils.rm_rf(@dir)
  end

  test "apps never see the Claude credentials" do
    output = ProjectShell.new(@dir).run("env")

    assert_no_match "sk-ant-oat01-secret", output
  end

  test "the agent gets them back explicitly" do
    output = ProjectShell.new(@dir).run("env", env: { "CLAUDE_CODE_OAUTH_TOKEN" => "sk-ant-oat01-for-agent" })

    assert_match "CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-for-agent", output
  end

  test "the agent runner passes the configured token" do
    original, Rails.configuration.x.claude_oauth_token = Rails.configuration.x.claude_oauth_token, "sk-ant-oat01-configured"

    assert_equal "sk-ant-oat01-configured", AgentRunner.new(projects(:clinic)).environment["CLAUDE_CODE_OAUTH_TOKEN"]
  ensure
    Rails.configuration.x.claude_oauth_token = original
  end
end
