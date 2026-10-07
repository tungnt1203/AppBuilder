# builder

The web app: describe an app, chat with the coding agent on the left, watch the live
preview on the right. Every project starts from the last commit of `../template`, in
`../projects/<slug>` with a git repository of its own.

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

The web server picks up code changes; the worker (`bin/jobs`) doesn't, so restart it after
changing the builder. It loads the code once because reloading would wait for the agent turns
it runs, which last many minutes, and Solid Queue would give up on the worker meanwhile. If a
worker dies mid-turn anyway, `RescueStrandedTurnsJob` (every minute) runs the turn again and
the agent resumes its session.

## How it works

- **Setup** (`ProjectSetupJob`): copy the template's last commit, set the app's name, language and time zone,
  install gems, prepare the database, start the preview server on the project's own port.
- **Turns** (`AgentTurnJob`): run the coding agent in the project. Its events become chat
  messages, a live activity line and a plan checklist (`AgentTranscript`). Afterwards the builder
  commits the change in the project's git repository (the agent names it) and restarts the
  preview. Messages can carry attached files (`Attachment`) and the part of the preview the
  owner pointed at (`PointedElement`).
- **Preview** (`PreviewServer`, `Project#restart_preview`): after setup, each turn and each
  restore, the builder runs `db:prepare` (new migrations) and the CSS build, restarts the app's
  server and opens its home page. A failure is kept as `preview_error` and shown over the preview
  with "Ask the agent to fix it" and "Try again"; publishing waits until it's fixed. While the
  agent is building, a screen covers the preview (the app may be halfway through a change), and
  the owner can peek underneath.
- **Private previews** (`PreviewGate`, the template's `config/initializers/preview_gate.rb`): a
  preview answers only to people the builder lets in. The studio opens it through
  `/projects/:id/preview`, which checks the account and redirects with a one-minute ticket signed
  with the project's `tmp/preview_secret`; the preview turns that into a cookie. The builder's
  own requests and the app's `bin/look` send a pass instead. Apps made before the gate stay open.
- **Agent backends** (`AgentRunner`, settings in `config/agent.yml`):
  - `cli`: the local `claude` command and your Claude Code login. Can only be stopped.
  - `sdk`: `runner/index.mjs` with the Claude Agent SDK, interactive: the agent asks questions
    with buttons, takes extra messages while it works and stops cleanly. Picked automatically
    after `npm install` in `runner/` when a token or `ANTHROPIC_API_KEY` is set.

## Sandbox: where projects run

Each project's preview server, gems, tests and the coding agent run in a Docker container of
its own that only sees the project's folder (`SANDBOX=docker`, the default):

```sh
bin/sandbox build            # once, and after changing sandbox/Dockerfile or runner/
bin/dev
bin/sandbox list             # the projects' containers
```

`SANDBOX=local` runs them directly on this machine, as your user: quicker when working on the
builder itself, but the agent can reach anything you can. Tests use `local`.

- The container is made when the project first needs it and kept; deleting the app removes it.
  The project's folder is mounted at the same path, so files, git history and the Code tab work
  as before. Git, publishing and screenshots stay on the host.
- The preview's port is published on `127.0.0.1` only. Gems are shared by all projects through
  the `appbuilder-gems` volume. The agent's Claude settings and sessions live in
  `storage/sandboxes/<slug>/`, so a container can be removed and made again.
- The agent needs a Claude token or `ANTHROPIC_API_KEY` (a container can't use your Claude Code
  login). It reaches the agent through the environment of `docker exec`, never its arguments.
- Each container may use `SANDBOX_CPUS` (2) and `SANDBOX_MEMORY` (2g); keep Docker's memory in
  mind when many previews run at once.

## Claude credentials

The agent in a container needs a long-lived token (it can't use your Claude Code login): run
`claude setup-token` and put it in the builder's encrypted credentials:

```sh
bin/rails credentials:edit
```

```yaml
claude:
  oauth_token: sk-ant-oat01-...
```

`CLAUDE_CODE_OAUTH_TOKEN` in the environment takes precedence. Only the agent process receives
the token: preview servers, tests and image builds of the apps run without it. A token belongs
to one Claude account; everyone running the builder uses their own. With `SANDBOX=local` and no
token, the agent uses your local `claude` login.

## Eval

`eval/prompts.yml` holds 60 first messages from imagined owners, written once by a model
(`bin/eval generate`): many kinds of business and group, from one line to a detailed brief,
mostly Vietnamese, some asking for an unusual look. Each run builds a random sample of them as
real projects, the way the studio builds them, then measures each: whether the build finished,
cost and time, the app's tests and rubocop, which pages open for a visitor and for the
signed-in owner, and a model's review of the screenshots. The review lists everything the
request explicitly asked for and marks each met, missed or unclear; **asked %** is the share
met of those it could see. It also scores look and phone from 1 to 10. Results and
`report.html` go to `storage/evals/<run>/`, compared with the run before. Each request costs
roughly $2–4 of agent usage.

The same seed picks the same sample, so compare runs on the same seed; use other seeds now and
then so the prompts aren't tuned to a few requests.

```sh
bin/eval                      # 8 requests (seed 1), three at a time
bin/eval -n 20 -s 2           # 20 requests, another sample
bin/eval p004 p017 -j 2       # these requests
bin/eval -m "shorter prompt"  # note what changed in this run
bin/eval report               # print the latest run again
bin/eval clean                # delete the apps of every run but the latest
bin/eval generate --force     # write a new prompt set (start a new baseline)
```

## Settings

Environment: `SANDBOX`, `SANDBOX_IMAGE`, `SANDBOX_CPUS`, `SANDBOX_MEMORY`, `SANDBOX_GEMS_VOLUME`,
`SANDBOXES_ROOT`, `PROJECTS_ROOT`, `TEMPLATE_PATH`, `AGENT_BACKEND`, `FIRST_PREVIEW_PORT`,
`CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`, `CHROME_BIN`, `THUMBNAILS_ROOT`, `REGISTRY`,
`ONCE_BIN`, `PUBLISH_DOMAIN`, `BACKUPS_ROOT`, and `UNSPLASH_ACCESS_KEY`, `PEXELS_API_KEY`,
`PIXABAY_API_KEY` for the agent's stock photo search (without them it uses Openverse).
The agent's tools, budget per turn and instructions are in `config/agent.yml`.

Limits for members (administrators have none): `APPS_PER_ACCOUNT` (default 2) and
`MONTHLY_BUDGET_USD` (default 20, or `none`), what the agent may cost for an account's apps
in a calendar month. Every turn's cost is kept in `usages`, also after its app is deleted. A
turn may spend what's left of the month's budget, up to the per-turn limit; with less than
$0.25 left, no turn starts. Members see their spending on the home page, admins everyone's in
Accounts.
