require "open3"

# Runs commands inside a project with that project's own Bundler setup,
# not the builder's. Claude credentials are removed from every command's
# environment, so the apps being built (their preview servers, tests and
# image builds) can never read them; only the agent gets them back, explicitly.
# The stock photo keys are kept from the apps the same way.
class ProjectShell
  Error = Class.new(StandardError)
  SECRETS = %w[ CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN UNSPLASH_ACCESS_KEY PEXELS_API_KEY PIXABAY_API_KEY ]

  def initialize(path)
    @path = path
  end

  def run(*command, env: {})
    output, status = Bundler.with_unbundled_env { Open3.capture2e(environment(env), *command, chdir: @path.to_s) }
    raise Error, "#{command.join(" ")} failed:\n#{output}" unless status.success?
    output
  rescue SystemCallError => error # the command or the project folder is missing
    raise Error, "#{command.join(" ")} failed: #{error.message}"
  end

  def spawn(*command, log:, env: {})
    Bundler.with_unbundled_env do
      Process.spawn(environment(env), *command, chdir: @path.to_s, out: log.to_s, err: log.to_s, pgroup: true).tap { |pid| Process.detach(pid) }
    end
  end

  def popen(*command, env: {}, &block)
    Bundler.with_unbundled_env { Open3.popen3(environment(env), *command, chdir: @path.to_s, &block) }
  end

  private
    def environment(env)
      SECRETS.index_with(nil).merge(env)
    end
end
