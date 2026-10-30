# syntax=docker/dockerfile:1
# The sandbox every project runs in when SANDBOX=docker: its preview server, its
# gems, tests and builds, and the coding agent. Build it with `bin/sandbox build`.
# The project's folder is mounted at the same path as on the host.

# Same Ruby as storefront/.ruby-version.
ARG RUBY_VERSION=3.3.10
FROM docker.io/library/ruby:$RUBY_VERSION-slim

# What the template's gems need to build and run, git and ripgrep for the agent,
# Node for Claude Code and the Agent SDK, and Chromium for the app's bin/look and system
# tests (with fonts for text the app's own fonts don't cover).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libvips libyaml-dev pkg-config \
      sqlite3 ripgrep procps nodejs npm ca-certificates chromium fonts-noto-core fonts-noto-color-emoji iptables && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# The agent: the claude command (backend "cli") and the Agent SDK runner (backend "sdk").
RUN npm install --global @anthropic-ai/claude-code && npm cache clean --force
WORKDIR /opt/runner
COPY runner/package.json runner/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY runner/index.mjs ./

# A plain user with the host user's id, so files it writes in the mounted project
# belong to the owner of the folder. The gems every project uses are in a volume at
# /usr/local/bundle that bin/sandbox gems fills as dev, read-only in the projects' containers.
ARG UID=1000
RUN useradd --create-home --uid $UID --shell /bin/bash dev && \
    mkdir -p /home/dev/.claude && chown -R dev:dev /home/dev /usr/local/bundle
ENV HOME=/home/dev BUNDLE_PATH=/usr/local/bundle BUNDLE_APP_CONFIG=/usr/local/bundle

# The container starts as root only to wall its network off (entrypoint.sh), then runs as dev;
# Sandbox::Docker runs every command in it as dev.
COPY sandbox/entrypoint.sh /usr/local/bin/sandbox-entrypoint
ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]
CMD ["sleep", "infinity"]
