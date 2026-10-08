"""The commerce-agents shopping assistant, on the Claude Agent SDK, selling from an AppBuilder
shop. One question, or a chat:

    APPBUILDER_SHOP_URL=https://shop.example.com APPBUILDER_STOREFRONT_KEY=sk_agent_... \
    python examples/shopping_console.py [--once "a black tee in M"]

The Agent SDK runs Claude Code underneath: it uses ANTHROPIC_API_KEY, or CLAUDE_CODE_OAUTH_TOKEN /
a signed-in `claude` for trying it out on your own machine.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import uuid

from claude_agent_sdk import ClaudeSDKClient
from shopping_agent import ShoppingAgentConfig
from shopping_agent_sdk import make_options, run_turn

from appbuilder_commerce import AppBuilderStorefront, ShopClient


async def main(question: str | None) -> None:
    backend = AppBuilderStorefront(ShopClient(os.environ["APPBUILDER_SHOP_URL"], os.environ["APPBUILDER_STOREFRONT_KEY"]))
    config = ShoppingAgentConfig(brand_name=os.environ.get("APPBUILDER_SHOP_NAME", "the shop"), assistant_name="Shop assistant")
    options, toolset = make_options(backend=backend, config=config, session_id=f"console-{uuid.uuid4()}", user_id="guest")
    async with ClaudeSDKClient(options=options) as client:
        questions = [question] if question else iter(lambda: input("you> ").strip(), "exit")
        for text in questions:
            result = await run_turn(client, text, toolset=toolset)
            print(f"\n{result.text}\n")
            for event in result.ui:
                print(f"--- {event['component']} ---\n{json.dumps(event['payload'], indent=2, default=str)[:1500]}\n")
            print(f"[tools: {', '.join(result.tool_calls)}]" + (f" [errors: {result.tool_errors}]" if result.tool_errors else ""))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", metavar="QUESTION")
    asyncio.run(main(parser.parse_args().once))
