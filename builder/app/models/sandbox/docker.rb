# Runs a project's code in a container of its own (see Sandbox): the project's folder is
# mounted at the same path, gems are shared by all projects through a volume, and the
# agent's Claude settings and sessions are kept on the host so they outlive the container.
# The preview's port is published on this machine's loopback only.
class Sandbox::Docker
  LABEL = "appbuilder.project"
  # Containers made before the network wall (sandbox/entrypoint.sh) are made again.
  WALL = "appbuilder.wall"
  WALL_VERSION = "1"
  RUNNING = "running"

  def initialize(project, host: ProjectShell.new(Rails.root))
    @project, @host = project, host
  end

  def name
    "appbuilder-#{@project.slug}"
  end

  # The agent can only reach the project's folder, so it may run any shell command.
  def isolated? = true

  # Makes the container, or starts it again after it stopped (Docker restarted, say).
  def start
    rebuild_unwalled
    case state
    when nil then create
    when RUNNING then nil
    else
      remove_orphans
      host.run("docker", "start", name)
    end
  end

  def remove
    host.capture("docker", "rm", "--force", name)
    FileUtils.rm_rf(home.dirname)
  end

  def run(*command, env: {})
    start
    host.run(*exec(command, env), env: env.compact)
  end

  def capture(*command, env: {})
    start
    host.capture(*exec(command, env), env: env.compact)
  end

  # In the background; its output goes to the log, which is in the project's folder. Like the
  # agent's secrets, env reaches it by name through the docker client's environment.
  def spawn(*command, log:, env: {})
    start
    host.run(*exec([ "sh", "-c", 'exec "$@" >> "$0" 2>&1', log.to_s, *command ], env, detach: true), env: env.compact)
    nil
  end

  # Secrets reach the agent through the docker client's environment (--env NAME), never
  # its arguments, where anyone on this machine could read them. It runs as a process
  # group whose id is kept in tmp/agent.pid, to stop it with the commands it started.
  def run_agent(*command, env:, &block)
    start
    secrets = env.compact
    raise ProjectShell::Error, "The Docker sandbox needs a Claude token (claude setup-token) or ANTHROPIC_API_KEY" unless
      secrets.key?("CLAUDE_CODE_OAUTH_TOKEN") || secrets.key?("ANTHROPIC_API_KEY")

    # --wait: docker exec's process already leads a group, so setsid forks, and without it
    # would return at once and leave the agent running with nobody reading it.
    wrapped = [ "setsid", "--wait", "sh", "-c", 'echo $$ > tmp/agent.pid; exec "$@"', "agent", *command ]
    host.popen(*exec(wrapped, secrets, interactive: true), env: secrets, &block)
  end

  def stop_agent(pid)
    group = agent_pid_file.read.to_i if agent_pid_file.exist?
    kill(-group) if group&.positive?
  rescue Errno::ESRCH
  ensure
    begin
      Process.kill("TERM", pid) if pid # the docker client
    rescue Errno::ESRCH
    end
  end

  # A process of the project's, by its id inside the container (a negative id is a group).
  def kill(pid, signal: "TERM")
    raise Errno::ESRCH unless state == RUNNING
    _, killed = host.capture("docker", "exec", "--user", "dev", name, "kill", "-#{signal}", "--", pid.to_s)
    raise Errno::ESRCH unless killed
  end

  # Whether something in the container listens on the port. Docker accepts connections to
  # a published port even when nothing listens behind it, so this looks inside.
  def listening?(port)
    return false unless state == RUNNING

    tables, read = host.capture("docker", "exec", "--user", "dev", name, "cat", "/proc/net/tcp", "/proc/net/tcp6")
    read && self.class.listening_in?(tables, port)
  end

  # In /proc/net/tcp a listening socket has state 0A and its address ends in the port, in hex.
  def self.listening_in?(tables, port)
    hex = format(":%04X", port)
    tables.lines.any? do |line|
      fields = line.split
      fields[1]&.end_with?(hex) && fields[3] == "0A"
    end
  end

  def runner_script
    "/opt/runner/index.mjs"
  end

  # Inside the container; Docker publishes the port on the host's loopback only.
  def bind_address
    "0.0.0.0"
  end

  def state
    output, found = host.capture("docker", "inspect", "--format", "{{.State.Status}}", name)
    output.strip if found
  end

  private
    def create
      raise ProjectShell::Error, "#{@project.name} was deleted" unless Project.exists?(@project.id)

      remove_orphans
      home.mkpath
      config = Rails.configuration.x
      path = @project.path.to_s
      host.run("docker", "run", "--detach", "--init", "--name", name, "--label", "#{LABEL}=#{@project.slug}", "--label", "#{WALL}=#{WALL_VERSION}",
        # Root and NET_ADMIN for the entrypoint's firewall only; it hands over to dev without either.
        "--user", "root", "--cap-add", "NET_ADMIN", "--env", "SANDBOX_HOST_PORTS=#{platform_port}",
        "--publish", "127.0.0.1:#{@project.port}:#{@project.port}",
        "--volume", "#{path}:#{path}", "--volume", "#{config.sandbox_gems_volume}:/usr/local/bundle",
        "--volume", "#{home}:/home/dev/.claude", *read_only_blocks(path), "--workdir", path,
        "--add-host", "host.docker.internal:host-gateway", # the Platform, for a storefront's preview
        "--cpus", config.sandbox_cpus.to_s, "--memory", config.sandbox_memory, "--pids-limit", "1024",
        config.sandbox_image)
    rescue ProjectShell::Error
      # A run that fails partway (its port taken, say) can leave the container behind,
      # running without its port; remove it so the next start makes it properly.
      host.capture("docker", "rm", "--force", name)
      raise
    end

    # The Platform's port on this machine, the one thing there the container may reach.
    def platform_port
      URI(Rails.configuration.x.platform_url_from_containers.to_s).port || 3000
    rescue URI::InvalidURIError
      3000
    end

    # A container from before the wall, when no turn is running in it: removed, to be made again
    # walled (its files are all in mounted folders).
    def rebuild_unwalled
      label, found = host.capture("docker", "inspect", "--format", "{{index .Config.Labels \"#{WALL}\"}}", name)
      return unless found && label.strip != WALL_VERSION && !@project.working?

      host.capture("docker", "rm", "--force", name)
    end

    # The blocks (vendor/blocks/storefront_kit) are the same in every app and updated as a whole: inside the
    # container, the agent can read them but not change them.
    def read_only_blocks(path)
      blocks = File.join(path, "vendor/blocks")
      File.directory?(blocks) ? [ "--volume", "#{blocks}:#{blocks}:ro" ] : []
    end

    # Containers of apps that no longer exist (deleted while a job was starting their preview),
    # which would hold on to a port a new app gets.
    def remove_orphans
      output, listed = host.capture("docker", "ps", "--all", "--filter", "label=#{LABEL}", "--format", "{{.Label \"#{LABEL}\"}}")
      return unless listed

      slugs = output.split
      orphans = slugs - Project.where(slug: slugs).pluck(:slug)
      orphans.each { |slug| host.capture("docker", "rm", "--force", "appbuilder-#{slug}") }
    end

    def exec(command, env, interactive: false, detach: false)
      [ "docker", "exec", *("--interactive" if interactive), *("--detach" if detach),
        "--user", "dev", *env.compact.keys.flat_map { |key| [ "--env", key ] }, "--workdir", @project.path.to_s, name, *command ]
    end

    # The agent's ~/.claude: settings, sessions to resume, plans.
    def home
      Rails.configuration.x.sandboxes_root.join(@project.slug, "claude")
    end

    def agent_pid_file
      @project.path.join("tmp/agent.pid")
    end

    def host
      @host
    end
end
