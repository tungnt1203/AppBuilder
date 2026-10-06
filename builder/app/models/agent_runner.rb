require "json"

# Runs one turn of the coding agent in a project and yields each event
# (a Claude Agent SDK message, parsed from a JSON line) as it happens.
#
# The "sdk" backend is interactive: while it runs, the owner's answers, extra
# messages and Stop (AgentCommand) are delivered to it on stdin. The "cli"
# backend can only be stopped, by ending its process.
class AgentRunner
  COMMAND_POLL = 0.3 # seconds
  # mode "plan" reads and proposes without changing anything; "build" makes the changes.
  def initialize(project, mode: "build", backend: Rails.configuration.x.agent_backend, config: Rails.configuration.x.agent)
    @project, @mode, @backend, @config = project, mode, backend, config
  end

  def self.stop(project)
    project.agent_commands.create!(kind: :interrupt)
    Process.kill("TERM", project.agent_pid) if project.agent_pid && Rails.configuration.x.agent_backend == "cli"
  rescue Errno::ESRCH
  end

  # An agent process that outlived the job running it (the job process restarted).
  def self.end_leftover(project)
    Process.kill("TERM", project.agent_pid) if project.agent_pid
  rescue Errno::ESRCH
  ensure
    project.update_column(:agent_pid, nil)
  end

  def run(prompt)
    with_config_file do |config_path|
      @project.shell.popen(*command(prompt, config_path), env: env) do |stdin, stdout, stderr, wait|
        @project.update_column(:agent_pid, wait.pid)
        courier = interactive? ? Thread.new { deliver_commands(stdin, wait) } : stdin.close
        errors = Thread.new { stderr.read }
        stdout.each_line { |line| yield parse(line) if line.strip.present? }
        status = wait.value
        raise ProjectShell::Error, "Agent exited with #{status.exitstatus}: #{errors.value.last(2000)}" unless status.success? || @project.stop_requested?
      ensure
        courier.kill if courier.is_a?(Thread)
        end_process(wait) # the job is being cut off, for example by a restart
        @project.update_column(:agent_pid, nil)
      end
    end
  end

  def interactive?
    @backend == "sdk"
  end

  def environment
    env
  end

  def command(prompt, config_path = nil)
    case @backend
    when "cli" then cli_command(prompt)
    when "sdk" then sdk_command(prompt, config_path)
    else raise ArgumentError, "Unknown agent backend #{@backend.inspect}"
    end
  end

  private
    def cli_command(prompt)
      [ "claude", "-p", prompt,
        "--output-format", "stream-json", "--verbose", "--include-partial-messages",
        "--setting-sources", "project",
        "--permission-mode", permission_mode,
        "--allowedTools", *@config[:allowed_tools],
        "--disallowedTools", *@config[:disallowed_tools],
        "--append-system-prompt", @config[:append_system_prompt],
        "--max-budget-usd", @config[:max_budget_usd].to_s,
        *([ "--resume", @project.session_id ] if @project.session_id) ]
    end

    def sdk_command(prompt, config_path)
      [ "node", Rails.root.join("runner/index.mjs").to_s,
        "--cwd", @project.path.to_s, "--prompt", prompt, "--config", config_path.to_s, "--permission-mode", permission_mode,
        *([ "--resume", @project.session_id ] if @project.session_id) ]
    end

    def permission_mode
      @mode == "plan" ? "plan" : "acceptEdits"
    end

    # The agent is the only process that gets the Claude credentials and the stock photo
    # keys for bin/images (see ProjectShell). It must not think it's nested inside another
    # Claude Code session either.
    def env
      { "CLAUDECODE" => nil, "CLAUDE_CODE_ENTRYPOINT" => nil,
        "CLAUDE_CODE_OAUTH_TOKEN" => Rails.configuration.x.claude_oauth_token,
        "ANTHROPIC_API_KEY" => ENV["ANTHROPIC_API_KEY"],
        **Rails.configuration.x.stock_photo_keys }
    end

    def end_process(wait)
      Process.kill("TERM", wait.pid) if wait.alive?
    rescue Errno::ESRCH
    end

    def deliver_commands(stdin, wait)
      while wait.alive?
        Rails.application.executor.wrap do
          @project.agent_commands.pending.each do |command|
            stdin.puts(command.to_line)
            stdin.flush
            command.delivered!
          end
        end
        sleep COMMAND_POLL
      end
    rescue IOError, Errno::EPIPE
      # The agent finished; anything not delivered is picked up by the next turn.
    end

    def with_config_file
      return yield(nil) unless @backend == "sdk"

      Tempfile.create([ "agent", ".json" ]) do |file|
        file.write({ allowedTools: @config[:allowed_tools], disallowedTools: @config[:disallowed_tools],
                     appendSystemPrompt: @config[:append_system_prompt], maxBudgetUsd: @config[:max_budget_usd] }.to_json)
        file.flush
        yield file.path
      end
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError
      { "type" => "unparsed", "text" => line }
    end
end
