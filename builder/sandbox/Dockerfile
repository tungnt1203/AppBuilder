# syntax=docker/dockerfile:1
# The sandbox every project runs in when SANDBOX=docker: its preview server, its
# gems, tests and builds, and the coding agent. Build it with `bin/sandbox build`.
# The project's folder is mounted at the same path as on the host.

# Same Ruby as template/.ruby-version.
ARG RUBY_VERSION=3.3.10
FROM docker.io/library/ruby:$RUBY_VERSION-slim

# What the template's gems need to build and run, git and ripgrep for the agent,
# Node for Claude Code and the Agent SDK, and Chromium for the app's bin/look and system
# tests (with fonts for text the app's own fonts don't cover).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libvips libyaml-dev pkg-config \
      sqlite3 ripgrep procps nodejs npm ca-certificates chromium fonts-noto-core fonts-noto-color-emoji && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# The agent: the claude command (backend "cli") and the Agent SDK runner (backend "sdk").
RUN npm install --global @anthropic-ai/claude-code && npm cache clean --force
WORKDIR /opt/runner
COPY runner/package.json runner/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY runner/index.mjs ./

# A plain user with the host user's id, so files it writes in the mounted project
# belong to the owner of the folder. Gems are shared by every project through a volume
# mounted at /usr/local/bundle, so it owns that too.
ARG UID=1000
RUN useradd --create-home --uid $UID --shell /bin/bash dev && \
    mkdir -p /home/dev/.claude && chown -R dev:dev /home/dev /usr/local/bundle
USER dev
ENV HOME=/home/dev BUNDLE_PATH=/usr/local/bundle BUNDLE_APP_CONFIG=/usr/local/bundle

CMD ["sleep", "infinity"]
