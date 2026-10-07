# CLAUDE.md

This is a Rails 8 app that its owner self-hosts with ONCE (https://github.com/basecamp/once).
The people describing features are usually not programmers: build what they ask for as a
complete, working feature, and explain the result in plain language. Reply entirely in the
language the owner writes in.

## SPEC.md: what was asked and what was chosen

SPEC.md is the app's checklist, kept across turns. At the start of every turn that builds or
changes something:

- Under **Asked**, add each thing the owner asked for in this message, one line each, close to
  their words and with their specifics (names, prices, colors, sections, rules, who may do what):
  `- [ ] Trang chủ nền đen, điểm nhấn vàng đồng, không dùng màu hồng`. When they change their
  mind, change or remove the old line; never keep two lines that disagree.
- Under **Chosen**, list what you decided where they said nothing that matters to them: who can
  sign up, what's public, the look, sample content: `- Khách đặt lịch không cần tài khoản`.

Before you finish, check every unchecked line under Asked against the app itself (the running
app with `bin/look`, the tests, the code), and tick it (`- [x]`) only when it's true there. A line
you can't meet stays unticked; say why in your reply. Answers to your questions and approved
plans count as asked. Never tick for the owner what you only planned.

The owner's words outrank everything else here, the skills' suggestions and the page blocks
included: when they ask for something unusual, build that rather than what such apps usually look
like. If it would hurt the people using the app (text too pale to read, a page that breaks on
phones), build it as close as works and say why.

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
- `bin/rails test:system` — the main flows in headless Chrome (`test/system/`); must pass too
- `bin/look /path --as owner` — look at pages of the running app: screenshots at phone and desktop
  width (Read them) and the problems a visitor would hit
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
  and are designed freely: header, footer, sections, imagery, motion. Start from the page blocks in
  `app/views/blocks/` (seen at `/_blocks`), copied into the page and made the app's own. See the `design` skill.
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

- Every line under Asked in SPEC.md is ticked, or your reply says why it isn't.
- The feature works end to end from the browser, including empty states and validation errors.
- Model tests for validations and business rules; integration tests for each controller action,
  including who may and may not access it; a system test for each main flow (`new-feature` skill).
- `bin/rails test`, `bin/rails test:system` and `bin/rubocop` pass.
- You looked at every page you changed with `bin/look`, at phone and desktop width, and fixed what
  it reported and what looked wrong.
- Your summary says what changed in terms the owner understands, and flags anything that affects
  existing data.

Use the `new-feature` skill when adding a screen or resource, and the `design` skill for how it looks.
