require "socket"

# The project's own `bin/rails server`, shown in the builder's preview iframe.
class PreviewServer
  BOOT_TIMEOUT = 30.seconds

  def initialize(project)
    @project = project
  end

  def start
    return if running?

    @project.shell.spawn("bin/rails", "server", "-p", @project.port.to_s, "-b", "127.0.0.1", log: log_path)
    wait_until { running? }
  end

  def stop
    pid = pid_path.exist? && pid_path.read.to_i
    Process.kill("TERM", pid) if pid&.positive?
    wait_until { !running? }
  rescue Errno::ESRCH
    pid_path.delete if pid_path.exist?
  end

  def restart
    stop
    start
  end

  def running?
    Socket.tcp("127.0.0.1", @project.port, connect_timeout: 0.2).close
    true
  rescue SystemCallError, IOError
    false
  end

  private
    def pid_path
      @project.path.join("tmp/pids/server.pid")
    end

    def log_path
      @project.path.join("log/preview.log")
    end

    def wait_until(timeout: BOOT_TIMEOUT)
      deadline = timeout.from_now
      sleep 0.25 until yield || Time.current > deadline
    end
end
