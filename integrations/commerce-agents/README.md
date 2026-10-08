# AppBuilder × commerce-agents

Backends that let the agents of [anthropics/commerce-agents](https://github.com/anthropics/commerce-agents)
work on a shop made with AppBuilder, through the shop's agent API (`/agent/v1`, in
`blocks/shop`):

- `AppBuilderStorefront` (`StorefrontBackend`): the shopping assistant for buyers. It searches
  the catalog, answers from the shop's policies, fills a cart for its conversation and hands it
  to the buyer's browser (a link that opens the shop's own checkout). It never takes payment.
- `AppBuilderMerchant` (`MerchantBackend`): the owner's assistant. It reads sales, stock, slow
  movers and order issues, and stages price changes, restocks, pauses, text edits and sales.
  Staged changes wait in the shop's `/admin` under Suggestions until someone applies them, from
  there or through the assistant. Campaigns and SQL analysis are things the shop doesn't have;
  the assistant is told so.

## Connect a shop

In the shop's `/admin`, Settings → AI agents, make a key for each assistant. Keys are shown once.

## Install

The agent packages aren't on PyPI; install them from a checkout of commerce-agents, then this:

```sh
git clone https://github.com/anthropics/commerce-agents.git
python -m venv .venv && source .venv/bin/activate
pip install -r commerce-agents/requirements.txt
pip install -e "integrations/commerce-agents[test]"
```

## Use

```python
from appbuilder_commerce import AppBuilderStorefront, AppBuilderMerchant, ShopClient

storefront = AppBuilderStorefront(ShopClient("https://shop.example.com", "sk_agent_..."))
merchant = AppBuilderMerchant(ShopClient("https://shop.example.com", "mk_agent_..."))
```

Pass them as the `backend` of any of the runtimes (Messages API, Agent SDK, or the MCP servers
for Managed Agents). Each conversation's `session_id` is its cart. To show a signed-in customer
their orders, pass `customer_email=lambda session: ...` to `AppBuilderStorefront`, from your own
authentication; the shop trusts it because it trusts the key. The merchant session's `operator`
is stamped on every change.

Two consoles on the Agent SDK runtime:

```sh
APPBUILDER_SHOP_URL=... APPBUILDER_STOREFRONT_KEY=... python examples/shopping_console.py --once "a black tee in M, two please"
APPBUILDER_SHOP_URL=... APPBUILDER_MERCHANT_KEY=... python examples/merchant_console.py --operator Olivia
```

The Agent SDK runs Claude Code: it takes `ANTHROPIC_API_KEY`, or for trying it on your own
machine `CLAUDE_CODE_OAUTH_TOKEN` or a signed-in `claude`. An assistant that serves a shop's
customers needs an API key.

## Test

`tests/test_live_shop.py` runs against a running shop with its sample catalog (and writes a
cart and a few changes it reverts):

```sh
APPBUILDER_SHOP_URL=http://localhost:3000 APPBUILDER_STOREFRONT_KEY=... APPBUILDER_MERCHANT_KEY=... pytest
```

Ids are the shop's: `product-<slug>` for a product (a family when it has options) and
`variant-<id>` for a variant.
