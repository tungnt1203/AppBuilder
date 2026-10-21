# blocks

The parts of generated storefronts that are built once and kept the same in every storefront,
packaged as gems, so storefronts get fixes by replacing the gem instead of in copied code. The
shop's data and money logic (catalog, checkout, orders, Stripe, Printify) live on the Platform
(`builder/`), not here.

| Block   | What it is |
|---------|------------|
| `storefront_kit/` | What a storefront uses to call the Storefront API (client, records, cache, helpers); used by `storefront/` |

The storefront template uses each block through a symlink in `storefront/vendor/blocks/`; a new
storefront gets a real copy there (`ProjectSetupJob`), so its preview, sandbox and Docker image have it.
