# builder

The web app: describe an app, chat with the coding agent on the left, watch the live
preview on the right. Every project is a copy of `../template` in `../projects/<slug>`.

## Run locally

```sh
bin/setup --skip-server
bin/dev
```

`bin/dev` runs the web server and the job worker (`bin/jobs`) as separate processes. Jobs go
through Solid Queue and reach the browser through Solid Cable, so restarting the web server
never interrupts the agent. If the worker restarts mid-turn, the turn runs again and the agent
resumes its session where it left off. To run them yourself:

```sh
bin/rails tailwindcss:build
bin/rails server -d
bin/jobs
```

Open http://localhost:3000.

## How it works

- **Setup** (`ProjectSetupJob`): clone the template, set the app's name, language and time zone,
  install gems, prepare the database, start the preview server on the project's own port.
- **Turns** (`AgentTurnJob`): run the coding agent in the project. Each event becomes a chat
  message (`AgentEvent`). Afterwards the builder rebuilds CSS, commits the change in the
  project's git repository and restarts the preview.
- **Preview** (`PreviewServer`, `Project#restart_preview`): after setup, each turn and each
  restore, the builder runs `db:prepare` (new migrations) and the CSS build, restarts the app's
  server and opens its home page. A failure is kept as `preview_error` and shown over the preview
  with "Ask the agent to fix it" and "Try again"; publishing waits until it's fixed. While the
  agent is building, a screen covers the preview (the app may be halfway through a change), and
  the owner can peek underneath.
- **Agent backends** (`AgentRunner`, settings in `config/agent.yml`):
  - `cli` (default without an API key): the local `claude` command and your Claude Code login.
  - `sdk`: `runner/index.mjs` with the Claude Agent SDK. Needs `ANTHROPIC_API_KEY`
    and `npm install` in `runner/`.

## Claude credentials

Without any setup the agent uses your local `claude` login. To use a long-lived token instead,
run `claude setup-token` and put it in the builder's encrypted credentials:

```sh
bin/rails credentials:edit
```

```yaml
claude:
  oauth_token: sk-ant-oat01-...
```

`CLAUDE_CODE_OAUTH_TOKEN` in the environment takes precedence. Only the agent process receives
the token: preview servers, tests and image builds of the apps run without it. A token belongs
to one Claude account; everyone running the builder uses their own.

Environment: `PROJECTS_ROOT`, `TEMPLATE_PATH`, `AGENT_BACKEND`, `FIRST_PREVIEW_PORT`,
`CLAUDE_CODE_OAUTH_TOKEN`.
