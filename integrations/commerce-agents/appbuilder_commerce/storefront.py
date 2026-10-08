"""``StorefrontBackend`` over an AppBuilder shop: its catalog, a cart per conversation, the
signed-in customer's orders, its policies and shipping. Checkout stays the shop's own: the
handoff is a link that moves the conversation's cart into the buyer's browser."""

from __future__ import annotations

from collections.abc import Callable

from shopping_agent import (
    Cart,
    CheckoutHandoff,
    FulfillmentOption,
    NotOffered,
    Order,
    Policy,
    Product,
    ProductDetails,
    SearchFilters,
    ShoppingSessionContext,
    StorefrontBackend,
    UserPreferences,
)
from shopping_agent import Unavailable as AgentUnavailable

from .client import NotFound, Refused, ShopClient, Unavailable

CustomerLookup = Callable[[ShoppingSessionContext], str | None]


class AppBuilderStorefront(StorefrontBackend):
    """``customer_email`` returns the email of the customer the host signed in for a session
    (None for a guest); the shop then shows that customer's orders. The shop trusts it because
    it trusts the key, so only a host that authenticates its customers should pass one."""

    def __init__(self, client: ShopClient, *, customer_email: CustomerLookup | None = None):
        self._client = client
        self._customer_email = customer_email or (lambda _session: None)

    def _headers(self, session: ShoppingSessionContext) -> dict[str, str]:
        headers = {"X-Agent-Session": session.session_id}
        if email := self._customer_email(session):
            headers["X-Agent-Customer"] = email
        return headers

    async def _get(self, session: ShoppingSessionContext, path: str, **params):
        return await self._client.request("GET", path, headers=self._headers(session), params=params)

    async def search_products(self, session, query, filters: SearchFilters | None = None, limit: int = 8) -> list[Product]:
        params = {"query": query, "limit": limit}
        if filters:
            if filters.category:
                params["category"] = filters.category
            if filters.min_price is not None:
                params["min_price"] = filters.min_price
            if filters.max_price is not None:
                params["max_price"] = filters.max_price
            params["sort"] = filters.sort
        body = await self._get(session, "/storefront/products", **params)
        return [Product.model_validate(product) for product in body["products"]]

    async def get_product_details(self, session, product_id) -> ProductDetails | None:
        try:
            return ProductDetails.model_validate(await self._get(session, f"/storefront/products/{product_id}"))
        except NotFound:
            return None

    async def get_cart(self, session) -> Cart:
        return Cart.model_validate(await self._get(session, "/storefront/cart"))

    async def add_to_cart(self, session, product_id, quantity) -> Cart:
        try:
            body = await self._client.request(
                "POST", "/storefront/cart/items", headers=self._headers(session), json={"product_id": product_id, "quantity": quantity}
            )
        except Unavailable as error:
            in_stock = f"; in stock: {', '.join(error.in_stock)}" if error.in_stock else ""
            raise AgentUnavailable(f"{product_id} is unavailable{in_stock}") from error
        except Refused as error:
            raise NotOffered(str(error)) from error
        return Cart.model_validate(body)

    async def update_cart_item(self, session, product_id, quantity) -> Cart:
        body = await self._client.request(
            "PATCH", f"/storefront/cart/items/{product_id}", headers=self._headers(session), json={"quantity": quantity}
        )
        return Cart.model_validate(body)

    async def remove_from_cart(self, session, product_id) -> Cart:
        body = await self._client.request("DELETE", f"/storefront/cart/items/{product_id}", headers=self._headers(session))
        return Cart.model_validate(body)

    async def checkout_handoff(self, session, cart) -> list[CheckoutHandoff]:
        body = await self._get(session, "/storefront/cart/handoff")
        return [CheckoutHandoff.model_validate(handoff) for handoff in body["handoffs"]]

    async def get_preferences(self, session) -> UserPreferences:
        body = await self._get(session, "/storefront/preferences")
        return UserPreferences.model_validate(body)

    async def get_orders(self, session, limit: int = 5) -> list[Order]:
        body = await self._get(session, "/storefront/orders", limit=limit)
        return [Order.model_validate(order) for order in body["orders"]]

    async def get_order(self, session, order_id) -> Order | None:
        try:
            return Order.model_validate(await self._get(session, f"/storefront/orders/{order_id.lstrip('#')}"))
        except NotFound:
            return None

    async def search_policies(self, session, query) -> list[Policy]:
        body = await self._get(session, "/storefront/policies", query=query)
        return [Policy.model_validate(policy) for policy in body["policies"]]

    async def get_fulfillment_options(self, session, product_ids) -> list[FulfillmentOption]:
        body = await self._get(session, "/storefront/fulfillment", **{"product_ids[]": product_ids})
        return [FulfillmentOption.model_validate(option) for option in body["options"]]
