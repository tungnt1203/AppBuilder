# Where a project's own code runs: its preview server, gems, tests and builds, and the
# coding agent. Git and publishing stay on the host (Project#shell).
#
# - "docker" (the default): in a container per project (sandbox/Dockerfile) that only
#   sees that project's folder. Needs `bin/sandbox build` and a Claude token or API key,
#   since the container can't use this machine's Claude login.
# - "local": directly on this machine, as the builder's user. Fast and simple for working
#   on the builder itself, but the agent can reach the whole machine.
module Sandbox
  def self.for(project)
    case Rails.configuration.x.sandbox
    when "local" then Local.new(project)
    when "docker" then Docker.new(project)
    else raise ArgumentError, "Unknown sandbox #{Rails.configuration.x.sandbox.inspect}"
    end
  end
end
