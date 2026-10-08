"""End to end against a running AppBuilder shop with its sample catalog (db/seeds.rb):

    APPBUILDER_SHOP_URL=http://localhost:3000 \
    APPBUILDER_STOREFRONT_KEY=sk_agent_... APPBUILDER_MERCHANT_KEY=mk_agent_... pytest

Skipped without them. It writes to the shop: a cart, and staged changes it discards (one price
change it applies and then puts back)."""

from __future__ import annotations

import os
import uuid

import httpx
import pytest

from appbuilder_commerce import AppBuilderMerchant, AppBuilderStorefront, ShopClient
from merchant_agent import ChangeNotApplicable, ChangeStatus, InventoryActionItem, MerchantSessionContext, PriceUpdateItem, PromotionDraft
from shopping_agent import ShoppingSessionContext, Unavailable

URL = os.environ.get("APPBUILDER_SHOP_URL")
pytestmark = [
    pytest.mark.skipif(not URL, reason="needs APPBUILDER_SHOP_URL and agent keys"),
    pytest.mark.asyncio,
]


@pytest.fixture
def storefront():
    return AppBuilderStorefront(ShopClient(URL, os.environ["APPBUILDER_STOREFRONT_KEY"]))


@pytest.fixture
def merchant():
    return AppBuilderMerchant(ShopClient(URL, os.environ["APPBUILDER_MERCHANT_KEY"]))


@pytest.fixture
def shopper():
    return ShoppingSessionContext(session_id=f"test-{uuid.uuid4()}", user_id="guest")


@pytest.fixture
def owner():
    return MerchantSessionContext(session_id="test", merchant_id="shop", operator="pytest")


async def test_wrong_key_is_refused(shopper):
    bad = AppBuilderStorefront(ShopClient(URL, "sk_agent_wrong"))
    with pytest.raises(Exception, match="401"):
        await bad.search_products(shopper, "")


async def test_search_details_and_a_family(storefront, shopper):
    products = await storefront.search_products(shopper, "", limit=20)
    assert products, "the sample catalog is seeded"
    family = next(product for product in products if product.has_options)

    details = await storefront.get_product_details(shopper, family.product_id)
    assert details.variants and all(variant.variant_of == family.product_id for variant in details.variants)
    assert all(set(variant.option_values) == set(family.options) for variant in details.variants)
    assert await storefront.get_product_details(shopper, "product-nothing-here") is None


async def test_cart_round_trip_and_handoff(storefront, shopper):
    products = await storefront.search_products(shopper, "", limit=20)
    family = next(product for product in products if product.has_options)
    variant = next(v for v in (await storefront.get_product_details(shopper, family.product_id)).variants if v.in_stock)

    cart = await storefront.add_to_cart(shopper, variant.product_id, 2)
    assert [(item.product_id, item.quantity) for item in cart.items] == [(variant.product_id, 2)]
    cart = await storefront.update_cart_item(shopper, variant.product_id, 3)
    assert cart.items[0].quantity == 3
    assert cart.items[0].option_values == variant.option_values

    [handoff] = await storefront.checkout_handoff(shopper, cart)
    async with httpx.AsyncClient() as http:
        response = await http.get(handoff.url)
    assert response.status_code == 302 and response.headers["location"].endswith("/checkout/new")

    cart = await storefront.remove_from_cart(shopper, variant.product_id)
    assert cart.items == []


async def test_a_paused_variant_is_unavailable(storefront, merchant, shopper, owner):
    family = next(product for product in await storefront.search_products(shopper, "", limit=20) if product.has_options)
    variant = (await storefront.get_product_details(shopper, family.product_id)).variants[0]
    pause = await merchant.stage_inventory_action(owner, [InventoryActionItem(listing_id=variant.product_id, action="pause")])
    await merchant.apply_change(owner, pause.change_id)
    try:
        with pytest.raises(Unavailable):
            await storefront.add_to_cart(shopper, variant.product_id, 1)
    finally:
        back = await merchant.stage_inventory_action(owner, [InventoryActionItem(listing_id=variant.product_id, action="activate")])
        await merchant.apply_change(owner, back.change_id)


async def test_policies_fulfillment_preferences_orders(storefront, shopper):
    product = (await storefront.search_products(shopper, "", limit=1))[0]
    assert (await storefront.get_fulfillment_options(shopper, [product.product_id]))[0].method == "shipping"
    assert (await storefront.get_preferences(shopper)).user_id == "guest"
    assert await storefront.get_orders(shopper) == []
    assert await storefront.get_order(shopper, "#1001") is None
    assert isinstance(await storefront.search_policies(shopper, "refund"), list)


async def test_reports(merchant, owner):
    snapshot = await merchant.get_business_snapshot(owner, "last_30_days")
    assert snapshot.period == "last_30_days" and snapshot.traffic is None
    series = await merchant.query_metrics(owner, "orders", "last_7_days")
    assert len(series.points) >= 7
    context = await merchant.get_merchant_context(owner)
    assert {limitation["source"] for limitation in context["limitations"]} == {"traffic", "campaigns"}
    assert isinstance(await merchant.get_inventory_alerts(owner), list)
    assert isinstance(await merchant.get_order_issues(owner), list)
    assert await merchant.get_campaign_performance(owner) == []


async def test_staged_price_change_applies_only_on_approval(merchant, owner):
    listing = (await merchant.search_listings(owner, "", limit=20))[0]
    details = await merchant.get_listing(owner, listing.listing_id)
    target = details.variants[0] if details.variants else details
    pricing = await merchant.get_pricing_context(owner, target.listing_id)
    old_price = pricing.current_price

    change = await merchant.stage_price_update(owner, [PriceUpdateItem(listing_id=target.listing_id, new_price=round(old_price + 1, 2))])
    assert change.status == ChangeStatus.STAGED
    assert (await merchant.get_pricing_context(owner, target.listing_id)).current_price == old_price
    assert change.change_id in {pending.change_id for pending in await merchant.get_pending_changes(owner)}

    applied = await merchant.apply_change(owner, change.change_id)
    assert applied.applied_by == "pytest"
    assert (await merchant.get_pricing_context(owner, target.listing_id)).current_price == round(old_price + 1, 2)
    with pytest.raises(ChangeNotApplicable):
        await merchant.apply_change(owner, change.change_id)

    back = await merchant.stage_price_update(owner, [PriceUpdateItem(listing_id=target.listing_id, new_price=old_price)])
    await merchant.apply_change(owner, back.change_id)


async def test_promotion_staged_then_discarded_and_refusals(merchant, owner):
    listing = (await merchant.search_listings(owner, "", limit=1))[0]
    draft = PromotionDraft(name="Test sale", listing_ids=[listing.listing_id], discount_pct=15, starts="2099-01-01", ends="2099-01-03")
    change = await merchant.stage_promotion(owner, draft)
    discarded = await merchant.discard_change(owner, change.change_id)
    assert discarded.status == ChangeStatus.DISCARDED and discarded.discarded_by == "pytest"

    with pytest.raises(ChangeNotApplicable):
        await merchant.stage_listing_update(owner, listing.listing_id, {"brand": "X"})
    with pytest.raises(ChangeNotApplicable):
        await merchant.stage_campaign(owner, None)
