require "json"

# Runs one turn of the coding agent in a project and yields each event
# (a Claude Agent SDK message, parsed from a JSON line) as it happens.
class AgentRunner
  def initialize(project, backend: Rails.configuration.x.agent_backend, config: Rails.configuration.x.agent)
    @project, @backend, @config = project, backend, config
  end

  def run(prompt)
    with_config_file do |config_path|
      @project.shell.popen(*command(prompt, config_path), env: env) do |stdin, stdout, stderr, wait|
        stdin.close
        errors = Thread.new { stderr.read }
        stdout.each_line { |line| yield parse(line) if line.strip.present? }
        raise ProjectShell::Error, "Agent exited with #{wait.value.exitstatus}: #{errors.value.last(2000)}" unless wait.value.success?
      end
    end
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
        "--output-format", "stream-json", "--verbose",
        "--setting-sources", "project",
        "--permission-mode", "acceptEdits",
        "--allowedTools", *@config[:allowed_tools],
        "--disallowedTools", *@config[:disallowed_tools],
        "--append-system-prompt", @config[:append_system_prompt],
        "--max-budget-usd", @config[:max_budget_usd].to_s,
        *([ "--resume", @project.session_id ] if @project.session_id) ]
    end

    def sdk_command(prompt, config_path)
      [ "node", Rails.root.join("runner/index.mjs").to_s,
        "--cwd", @project.path.to_s, "--prompt", prompt, "--config", config_path.to_s,
        *([ "--resume", @project.session_id ] if @project.session_id) ]
    end

    # Don't let the agent think it's nested inside another Claude Code session.
    def env
      { "CLAUDECODE" => nil, "CLAUDE_CODE_ENTRYPOINT" => nil }
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
