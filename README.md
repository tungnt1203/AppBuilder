# appbuilder workspace

An AI app builder for Rails: describe an app in a chat, watch it being built in a live
preview, and publish it to your own server with [ONCE](https://github.com/basecamp/once).
Working name only.

One repository with three parts:

| Repo        | What it is                                                        |
|-------------|-------------------------------------------------------------------|
| `template/` | The Rails 8 app every generated app starts from: ONCE-ready, with conventions and skills for Claude |
| `blocks/`   | Integration gems (VietQR + SePay, Zalo, Google login, ...)         |
| `builder/`  | The builder web app and the agent runner                           |

New apps start from the last commit of `template/` (see `ProjectSetupJob`); each generated
app gets a git repository of its own under `projects/`, which isn't part of this one.

## Plan

1. ✅ `template` runs on ONCE: deploy, update, failed update keeps the old version, backup and restore (verified locally with ONCE v0.3.3 on 2026-10-05).
2. ✅ Tune generation quality by running Claude Code inside `template` with sample prompts (two rounds, see `playground/`).
3. ✅ Preview per project (local `bin/rails server` on its own port; containers later).
4. ✅ Builder UI: chat + preview.
5. Versions and undo (one git commit per turn — commits done, undo not yet).
6. ✅ Publish: build image, push, `once deploy`, or backup + `once update --image`.
7. First block: VietQR + SePay.
8. Beta with real users.

## Local ONCE setup

- `once` binary in `~/.local/bin` (no background service, so no auto-update/auto-backup).
- Local registry: `docker run -d --restart=always --name local-registry -p 5050:5000 registry:2`
- Build and deploy:
  ```sh
  docker build -t localhost:5050/starter:v1 template && docker push localhost:5050/starter:v1
  once deploy localhost:5050/starter:v1 --host myapp.localhost --auto-update=false
  once update myapp.localhost --image localhost:5050/starter:v2
  ```
- ONCE disables TLS automatically for `*.localhost`.
