require "open3"

# Runs commands inside a project with that project's own Bundler setup,
# not the builder's.
class ProjectShell
  Error = Class.new(StandardError)

  def initialize(path)
    @path = path
  end

  def run(*command)
    output, status = Bundler.with_unbundled_env { Open3.capture2e(*command, chdir: @path.to_s) }
    raise Error, "#{command.join(" ")} failed:\n#{output}" unless status.success?
    output
  end

  def spawn(*command, log:, env: {})
    Bundler.with_unbundled_env do
      Process.spawn(env, *command, chdir: @path.to_s, out: log.to_s, err: log.to_s, pgroup: true).tap { |pid| Process.detach(pid) }
    end
  end

  def popen(*command, env: {}, &block)
    Bundler.with_unbundled_env { Open3.popen3(env, *command, chdir: @path.to_s, &block) }
  end
end
