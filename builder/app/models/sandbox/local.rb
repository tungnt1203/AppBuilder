require "socket"

# Runs a project's code directly on this machine (see Sandbox).
class Sandbox::Local
  def initialize(project)
    @project = project
  end

  # Runs on this machine, so the agent only gets the commands config/agent.yml allows.
  def isolated? = false

  def start
  end

  def remove
  end

  def run(*command, env: {})
    shell.run(*command, env:)
  end

  def capture(*command, env: {})
    shell.capture(*command, env:)
  end

  def spawn(*command, log:)
    shell.spawn(*command, log:)
  end

  # Yields the agent's stdin, stdout, stderr and waiter, like Open3.popen3. Variables set
  # to nil are removed from its environment.
  def run_agent(*command, env:, &block)
    shell.popen(*command, env:, &block)
  end

  def stop_agent(pid)
    kill(pid)
  end

  # A process of the project's, by the id it has where it runs.
  def kill(pid, signal: "TERM")
    Process.kill(signal, pid)
  end

  def runner_script
    Rails.root.join("runner/index.mjs").to_s
  end

  def listening?(port)
    Socket.tcp("127.0.0.1", port, connect_timeout: 0.2).close
    true
  rescue SystemCallError, IOError
    false
  end

  # Only this machine opens the preview.
  def bind_address
    "127.0.0.1"
  end

  private
    def shell
      @project.shell
    end
end
