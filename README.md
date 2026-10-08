# AppBuilder

An AI app builder for Rails. Describe an app in a chat, watch a coding agent build it in a live
preview next to the chat, and publish it to your own server with
[ONCE](https://github.com/basecamp/once). Made first for small businesses (nail salons, clinics,
cafés, boarding houses…), in Vietnamese and English. Working name only.

> **Status: early, runs on one machine.** The agent and the previews run directly on the
> machine that runs the builder, with access to its files. Don't open it to other people
> until each project runs in its own container (see [Roadmap](#roadmap)).

## What it does

- **Chat to build**: plan first or build right away; the agent asks when something important is
  unclear, shows its plan as a checklist, and suggests what to ask for next.
- **Live preview** of the real Rails app, at desktop, tablet and phone sizes, with a Code tab.
  Errors in the preview come with a "Fix this error" button.
- **Point and attach**: point at a part of the preview to talk about it; attach a logo, photos,
  a menu as PDF or screenshots.
- **Versions**: every turn is a git commit; go back to any version from the chat or History.
- **Publish** to ONCE at `<name>.<your domain>`, with a backup before every update.
- **Eval**: `bin/eval` builds a random sample of 60 varied owner requests and checks how much of
  what each asked for the app does, to tell whether a change made generated apps better or worse.

## What's in this repository

| Folder      | What it is                                                         | License |
|-------------|--------------------------------------------------------------------|---------|
| `builder/`  | The builder: studio web app, agent runner, publishing, eval         | AGPL-3.0 |
| `template/` | The Rails 8 app every generated app starts from: ONCE-ready, with auth, a UI kit, and `CLAUDE.md` + skills for the agent | MIT |
| `blocks/`   | The parts every generated app shares, as Rails engines: `shop/` (catalog, cart, checkout, orders, Stripe) | MIT |

New apps start from the last commit of `template/`, with a copy of each block it uses in
`vendor/blocks/` (see `ProjectSetupJob`): the core is built once there, and each app designs its own
screens on top of it. Each generated app
gets its own git repository under `projects/`, which isn't part of this one. The template and the
blocks are MIT so that the apps made with them belong to their owners; the template's
`LICENSE` isn't copied into those apps.

## Run it locally

You need macOS or Linux with:

- Ruby 3.3.10 (see `builder/.ruby-version`) and SQLite
- [Claude Code](https://claude.com/claude-code), signed in (`claude` on your `PATH`): the agent
  uses your Claude account. Or a token from `claude setup-token`, see `builder/README.md`.
- Google Chrome, for app thumbnails and `bin/eval` (`CHROME_BIN` if it's not in the default place)
- To publish: Docker, a local registry and the `once` command (see below)
- Optional: Node.js, for the interactive agent (`npm install` in `builder/runner`)

```sh
git clone https://github.com/tungnt1203/AppBuilder.git
cd AppBuilder/builder
bin/setup --skip-server
bin/dev
```

Open http://localhost:3000 and describe an app. Generated apps go to `../projects/`, each with
its preview server on its own port from 4001.

`builder/README.md` explains how the builder works, its settings and the eval.

### Publishing locally with ONCE

```sh
docker run -d --restart=always --name local-registry -p 5050:5000 registry:2
# install the once command: https://github.com/basecamp/once
```

The builder builds the app's image, pushes it to `localhost:5050` and deploys it with
`once deploy` at `http://<name>.localhost` (ONCE turns TLS off for `*.localhost`). Settings:
`REGISTRY`, `ONCE_BIN`, `PUBLISH_DOMAIN`, `BACKUPS_ROOT`.

## Roadmap

Done: the agent and each preview in a container per project (the default), private previews
that can be shared by link, the code as a zip, turns that survive a job worker restart,
accounts with a monthly budget for the agent.

Before other people use it:

1. Publish to a real server: a VPS, a domain, HTTPS, a private registry and real email.

Then: pushing an app to a GitHub repository, updating the blocks in existing apps, and a
`booking` block for appointment-based businesses.

## License

`builder/` is licensed under the [GNU AGPL v3](builder/LICENSE): if you run a modified builder
as a service for others, you share your changes under the same license. `template/` and
`blocks/` are [MIT](template/LICENSE).
