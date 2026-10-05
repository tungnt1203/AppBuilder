# Starter

The Rails 8 app that every generated app starts from. It runs on
[ONCE](https://github.com/basecamp/once) as-is and comes with:

- Sign in, first-run owner setup, invitations, and roles (owner, admin, member)
- `/admin/users` to manage people
- A small UI kit (`app/helpers/ui_helper.rb`, `app/views/ui/`, `UiFormBuilder`) on Tailwind 4
- `CLAUDE.md` and `.claude/skills/` so Claude Code builds features the same way every time

## Develop

```sh
bin/setup        # install gems, prepare the database, start bin/dev
bin/rails test
bin/rubocop
```

The first visit to http://localhost:3000 asks you to create the owner account.

## Run on ONCE

```sh
docker build -t localhost:5050/starter:v1 . && docker push localhost:5050/starter:v1
once deploy localhost:5050/starter:v1 --host myapp.localhost --auto-update=false
```

What the app expects from ONCE: HTTP on port 80, `/up` health check, data in `storage/`
(mounted at `/rails/storage`), backup hooks in `/hooks`, and configuration through
`BASE_URL`, `SMTP_*`, `MAILER_FROM_ADDRESS`, `DISABLE_SSL` and `SECRET_KEY_BASE`.
Solid Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA` is set in the Dockerfile), so
background jobs and emails work without a separate process.
