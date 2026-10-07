# Thinks of a short English name for an app from the owner's description (apps are in
# English whatever language the owner writes in). Takes several seconds, so it runs in the setup job;
# nil when no name came back in time (the provisional name stays).
class AppNamer
  TIMEOUT = 45 # seconds
  MODEL = "sonnet" # haiku is no faster here, and its names read like fragments

  def initialize(request)
    @request = request.to_s
  end

  def name
    clean(Timeout.timeout(TIMEOUT) { ask })
  rescue ProjectShell::Error, Timeout::Error => error
    Rails.logger.warn "AppNamer: no name (#{error.message.truncate(500)})"
    nil
  end

  def command
    [ "claude", "-p", prompt, "--model", MODEL, "--output-format", "text", "--setting-sources", "", "--tools", "", "--no-session-persistence" ]
  end

  def prompt
    "Name the web app described below like a real product or shop: short (2 to 4 words), memorable, " \
      "saying who it's for or what it does. Write it in English, in title case, even when the description " \
      "is in another language. Reply with the name only: no quotes, no explanation.\n\n#{@request.truncate(2000)}"
  end

  private
    def ask
      ProjectShell.new(Dir.tmpdir).run(*command, env: env)
    end

    # Same credentials as the agent, never the project's processes.
    def env
      AgentRunner.claude_env
    end

    def clean(output)
      line = output.to_s.lines.map(&:squish).find(&:present?).to_s
      line = line.delete("\"“”*`").sub(/[.。!]+\z/, "").squish
      line if line.present? && line.length <= 40
    end
end
