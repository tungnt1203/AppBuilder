require "test_helper"

class SandboxTest < ActiveSupport::TestCase
  # Records docker commands and answers `docker inspect` with the container's state.
  class FakeHost
    attr_reader :commands, :environments
    attr_accessor :state

    def initialize(state) = (@state, @commands, @environments = state, [], [])

    def run(*command, env: {})
      @commands << command
      @environments << env
      ""
    end

    def capture(*command, env: {})
      @commands << command
      command[1] == "inspect" ? [ "#{@state}\n", !@state.nil? ] : [ "", true ]
    end

    def popen(*command, env: {})
      @commands << command
      @environments << env
    end
  end

  setup do
    @project = projects(:clinic)
  end

  test "runs locally unless the docker sandbox is chosen" do
    assert_instance_of Sandbox::Local, @project.sandbox
    with_sandbox("docker") { assert_instance_of Sandbox::Docker, @project.sandbox }
  end

  test "makes the project's container on first use: its folder only, the preview on the host's loopback" do
    host = FakeHost.new(nil)
    Sandbox::Docker.new(@project, host:).run("bin/rails", "db:prepare")

    create = host.commands.find { |command| command[1] == "run" }
    path = @project.path.to_s
    assert_includes create.each_cons(2).to_a, [ "--publish", "127.0.0.1:4001:4001" ]
    assert_includes create.each_cons(2).to_a, [ "--volume", "#{path}:#{path}" ]
    assert_includes create.each_cons(2).to_a, [ "--name", "appbuilder-nha-khoa" ]
    assert_equal [ "docker", "exec", "--workdir", path, "appbuilder-nha-khoa", "bin/rails", "db:prepare" ], host.commands.last
  end

  test "removing the sandbox removes the container and the agent's settings" do
    home = Rails.configuration.x.sandboxes_root.join(@project.slug, "claude")
    home.mkpath
    host = FakeHost.new("running")

    Sandbox::Docker.new(@project, host:).remove

    assert_equal [ "docker", "rm", "--force", "appbuilder-nha-khoa" ], host.commands.last
    assert_not home.dirname.exist?
  end

  test "starts a stopped container, and leaves a running one" do
    host = FakeHost.new("exited")
    Sandbox::Docker.new(@project, host:).start
    assert_equal [ "docker", "start", "appbuilder-nha-khoa" ], host.commands.last

    host = FakeHost.new("running")
    Sandbox::Docker.new(@project, host:).start
    assert_equal 1, host.commands.size
  end

  test "secrets reach the agent through the environment, never its arguments" do
    host = FakeHost.new("running")
    Sandbox::Docker.new(@project, host:).run_agent("claude", "-p", "Hi", env: { "CLAUDE_CODE_OAUTH_TOKEN" => "sk-secret", "CLAUDECODE" => nil })

    command = host.commands.last
    assert_includes command.each_cons(2).to_a, [ "--env", "CLAUDE_CODE_OAUTH_TOKEN" ]
    assert_not command.any? { |argument| argument.include?("sk-secret") }
    assert_not_includes command, "CLAUDECODE"
    assert_equal({ "CLAUDE_CODE_OAUTH_TOKEN" => "sk-secret" }, host.environments.last)
    assert_equal [ "claude", "-p", "Hi" ], command.last(3)
  end

  test "the agent needs a token or API key in a container" do
    error = assert_raises(ProjectShell::Error) do
      Sandbox::Docker.new(@project, host: FakeHost.new("running")).run_agent("claude", env: { "CLAUDE_CODE_OAUTH_TOKEN" => nil })
    end
    assert_match "claude setup-token", error.message
  end

  test "the agent's runner and the preview's address are the container's" do
    sandbox = Sandbox::Docker.new(@project, host: FakeHost.new("running"))
    assert_equal "/opt/runner/index.mjs", sandbox.runner_script
    assert_equal "0.0.0.0", sandbox.bind_address
    assert_equal "127.0.0.1", Sandbox::Local.new(@project).bind_address
  end

  test "a port counts as open only when something in the container listens on it" do
    tables = <<~TABLE
        sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
         0: 00000000:0FA1 00000000:0000 0A 00000000:00000000 00:00000000 00000000   502        0 1
         1: 0100007F:1F90 0100007F:D2C4 01 00000000:00000000 00:00000000 00000000   502        0 2
    TABLE

    assert Sandbox::Docker.listening_in?(tables, 4001)
    assert_not Sandbox::Docker.listening_in?(tables, 8080) # connected, not listening
    assert_not Sandbox::Docker.listening_in?(tables, 4002)
  end

  private
    def with_sandbox(kind)
      original, Rails.configuration.x.sandbox = Rails.configuration.x.sandbox, kind
      yield
    ensure
      Rails.configuration.x.sandbox = original
    end
end
