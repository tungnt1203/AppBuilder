# blocks

The parts of generated apps that are built once and kept the same in every app, packaged as
Rails engines, so apps get fixes by replacing the gem instead of in copied code.

| Block   | What it is |
|---------|------------|
| `shop/` | Catalog, cart, checkout, orders, Stripe payments: the core of every app |
| `booking/` | Services, staff and their hours, free times, appointments, reminders; on with `config.x.booking` |

The template uses each block through a symlink in `template/vendor/blocks/`; a new app gets a
real copy there (`ProjectSetupJob`), so its preview, sandbox and Docker image have it.
