require "socket"
require "net/http"

# The project's own `bin/rails server`, shown in the builder's preview iframe.
class PreviewServer
  BOOT_TIMEOUT = 30.seconds
  CHECK_TIMEOUT = 30 # seconds; the first request in development compiles a lot

  def initialize(project)
    @project = project
  end

  def start
    return if running?

    pid_path.delete if pid_path.exist? # left by a server that's gone; in a restarted container its id may be taken
    url_path.write("http://127.0.0.1:#{@project.port}") # for the app's bin/look, inside the sandbox

    @project.sandbox.spawn("bin/rails", "server", "-p", @project.port.to_s, "-b", @project.sandbox.bind_address, log: log_path)
    wait_until { running? }
  end

  def stop
    pid = pid_path.read.to_i if pid_path.exist?
    @project.sandbox.kill(pid) if pid&.positive?
    wait_until { !running? }
  rescue Errno::ESRCH
    pid_path.delete if pid_path.exist?
  end

  def restart
    stop
    start
  end

  def running?
    @project.sandbox.listening?(@project.port)
  end

  # Opens the home page the way the owner would. Returns what went wrong, or nil
  # when the app answers (a redirect to sign in counts as working).
  def check
    return "The preview server didn't start.\n\n#{log_tail}".strip unless running?

    response = Net::HTTP.start("127.0.0.1", @project.port, open_timeout: 2, read_timeout: CHECK_TIMEOUT) { |http| http.get("/") }
    self.class.error_from(response.body) || "The home page answered #{response.code}." if response.code.to_i >= 500
  rescue Net::ReadTimeout
    "The preview didn't answer within #{CHECK_TIMEOUT} seconds."
  rescue SystemCallError, IOError => error
    "The preview couldn't be reached: #{error.message}"
  end

  # The heading, template location and message of Rails' development error page.
  def self.error_from(html)
    page = Nokogiri::HTML(html.to_s)
    template = page.css("p").find { |node| node.text.strip.start_with?("Showing") } # "Showing app/views/… where line #3 raised:"
    parts = [ page.at_css("header h1"), template, page.at_css(".exception-message .message") ]
    parts.filter_map { |node| node&.text&.squish.presence }.uniq.join("\n").presence
  end

  private
    def url_path
      @project.path.join("tmp/preview_url").tap { |path| path.dirname.mkpath }
    end

    def pid_path
      @project.path.join("tmp/pids/server.pid")
    end

    def log_path
      @project.path.join("log/preview.log")
    end

    def log_tail
      log_path.exist? ? log_path.readlines.last(15).join : ""
    end

    def wait_until(timeout: BOOT_TIMEOUT)
      deadline = timeout.from_now
      sleep 0.25 until yield || Time.current > deadline
    end
end
