# CLAUDE.md

This is a Rails 8 app that its owner self-hosts with ONCE (https://github.com/basecamp/once).
The people describing features are usually not programmers: build what they ask for as a
complete, working feature, and explain the result in plain language. Reply entirely in the
language the owner writes in.

## Language and time zone

Set these once, at the start of a new app, to match the owner (`config/application.rb`):

- `config.i18n.default_locale`: `:vi` for Vietnamese owners, otherwise `:en`.
- `config.time_zone`: where the app's users are, e.g. `"Asia/Ho_Chi_Minh"` for Vietnam.

The built-in screens (sign in, admin, emails) are already translated in `config/locales/en.yml` and
`vi.yml`, and rails-i18n translates validation errors, dates and numbers, so don't write those again.
Write new UI copy directly in the owner's language. Format with `l(date)`, `l(time, format: :short)`
and `number_to_currency`, which follow the locale (for example `150.000 VNĐ` and `05/10/2026` in Vietnamese).

## Stack (fixed)

Rails 8.1, SQLite, Solid Queue/Cache/Cable, Hotwire (Turbo + Stimulus), importmap, Tailwind CSS 4,
Minitest with fixtures. Do not add JavaScript frameworks, Node build steps, other databases,
Redis, or external services. Add a gem only when Rails cannot reasonably do the job.

## Commands

- `bin/rails test` — all tests; must pass before you report a task as done
- `bin/rubocop` — style; must be clean
- `bin/rails db:migrate` — after adding a migration
- `bin/rails tailwindcss:build` — after changing views, so the preview picks up new classes

## Running on ONCE (do not break)

- The app serves HTTP on port 80 through Thruster; `/up` must return 200 when the app is healthy.
- Everything that must survive restarts lives in `storage/` (SQLite databases, uploads). Never write
  persistent data anywhere else.
- Configuration comes from environment variables ONCE sets: `BASE_URL`, `SMTP_*`,
  `MAILER_FROM_ADDRESS`, `DISABLE_SSL`, `SECRET_KEY_BASE`. Never hard-code hosts, credentials or secrets.
- `hooks/pre-backup` and `hooks/post-restore` keep backups consistent; leave them alone.
- `config/initializers/preview_probe.rb` reports errors to the builder's preview in development; leave it as it is.

## Migrations must be backward compatible

When a new version fails its health check, ONCE keeps the previous version running, but migrations
from the new version may already have run. The previous code must keep working on the new schema:

- Adding tables, adding columns with a default or that allow NULL, and adding indexes are fine.
- Never remove or rename a column or table in the same change that stops using it. Stop using it first;
  removing it is a separate, later change.
- Never change existing data in a way the previous version can't read.

## Public pages and sign in

Decide for every screen who it's for. Not every app needs sign in:

- **Public**, for customers and visitors: landing pages, booking or order forms, product
  catalogs, menus, contact pages. Add `allow_unauthenticated_access` to the controller.
- **Signed in**, for the owner and staff: managing records, schedules, reports, settings.
  This is the default.

A public page must work for any visitor, on a brand-new install with no accounts yet. Never
redirect visitors from a public page to sign in or to the first-run setup; the owner reaches
those through the "Sign in" link or `/session/new`, which starts the first-run setup when no
account exists. Signed-in staff may be sent from a public page to their own screen with
`redirect_to ... if authenticated?`. In views of public pages, check `authenticated?` before
using `Current.user`. Test public pages with no users at all (`User.delete_all`).

## Accounts and permissions

Built in, extend rather than replace:

- `Current.user` is the signed-in user. Every controller requires sign in unless it calls
  `allow_unauthenticated_access`.
- Roles: `owner` (created on first run, permanent), `admin`, `member`. `user.administrator?` is true
  for owner and admin.
- People are managed in `/admin/users` (invite, change role, remove). Controllers that only admins
  may use inherit from `Admin::BaseController`.
- Records that belong to someone use `belongs_to :user` (or a clearer name like `:author`) and scope
  queries through it when members should only see their own data.

## Design and UI

Every app gets a look of its own, chosen for its business and its customers. Read `DESIGN.md` before
touching views; on a new app it says "Not decided yet": choose the direction with the `design` skill
first and write it there. A plan for a new app includes a short "Look and feel" section.

- Theme (colors, fonts, corners): `app/assets/tailwind/application.css`. The template's theme is a
  neutral placeholder; replace it with the app's direction. Fonts are self-hosted (`fonts.css`, all with
  Vietnamese); icons are Lucide via `icon "name"` (find names with `bin/icons <word>`); free stock
  photos come from `bin/images <english words>` (see the `design` skill).
- **Customer-facing pages** (home, catalog, menu, booking, anything visitors use) use `layout "public"`
  and are designed freely: header, footer, sections, imagery, motion. See the `design` skill.
- **The owner's and staff's screens** (managing records, schedules, reports, settings) use the
  `application` layout (sidebar) and the UI kit in `app/helpers/ui_helper.rb` (`ui-kit` skill):
  `page_header`, `card`, `stat`, `empty_state`, `badge`, `alert`, `tabs`, `dialog`, `menu`,
  `button_classes`… Forms everywhere use `form.field`, `form.errors`, `form.submit` (`UiFormBuilder`).
- Sign-in screens use `authentication`. Add each owner screen to `app/views/layouts/_navigation.html.erb`.
- Interactivity comes from Turbo (Frames, Streams, morphing) and Stimulus (`shell`, `dialog`, `menu`,
  plus small controllers of your own).
- Set the app's name in `config.x.app_name` (`config/application.rb`).
- When the app gets its real main screen, point `root` at it and delete the placeholder
  (`HomeController`, `app/views/home/`, `test/controllers/home_controller_test.rb`, and the `home:` keys
  in both locale files). Keep the `layouts.application.home` key only if the nav still says "Home".

## Definition of done

- The feature works end to end from the browser, including empty states and validation errors.
- Model tests for validations and business rules; integration tests for each controller action,
  including who may and may not access it.
- `bin/rails test` and `bin/rubocop` pass.
- Your summary says what changed in terms the owner understands, and flags anything that affects
  existing data.

Use the `new-feature` skill when adding a screen or resource, and the `design` skill for how it looks.
