"""The commerce-agents assistant for the shop's owner, on the Claude Agent SDK, over an
AppBuilder shop. Its changes are staged in the shop (/admin, Suggestions) until applied:

    APPBUILDER_SHOP_URL=https://shop.example.com APPBUILDER_MERCHANT_KEY=mk_agent_... \
    python examples/merchant_console.py --operator "Olivia" [--once "How are sales?"]

Authentication as in shopping_console.py.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import uuid

from claude_agent_sdk import ClaudeSDKClient
from merchant_agent import MerchantAgentConfig
from merchant_agent_sdk import make_options, run_turn

from appbuilder_commerce import AppBuilderMerchant, ShopClient


async def main(question: str | None, operator: str) -> None:
    backend = AppBuilderMerchant(ShopClient(os.environ["APPBUILDER_SHOP_URL"], os.environ["APPBUILDER_MERCHANT_KEY"]))
    config = MerchantAgentConfig(store_name=os.environ.get("APPBUILDER_SHOP_NAME", "the shop")) if "store_name" in MerchantAgentConfig.model_fields else MerchantAgentConfig()
    options, toolset = make_options(backend=backend, config=config, session_id=f"console-{uuid.uuid4()}", merchant_id="shop", operator=operator)
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
    parser.add_argument("--operator", default=os.environ.get("USER", "owner"))
    args = parser.parse_args()
    asyncio.run(main(args.once, args.operator))
