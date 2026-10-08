"""``MerchantBackend`` over an AppBuilder shop. The shop stages every change itself (they show
up in its /admin under Suggestions too) and only writes on apply; campaigns and SQL analysis
are things it doesn't have, said so in the merchant context."""

from __future__ import annotations

from typing import Any

from merchant_agent import (
    ActorKind,
    BusinessSnapshot,
    Campaign,
    CampaignDraft,
    ChangeNotApplicable,
    InventoryActionItem,
    InventoryAlert,
    Listing,
    ListingDetails,
    ListingFilters,
    MerchantBackend,
    MerchantSessionContext,
    MetricSeries,
    OrderIssue,
    PriceUpdateItem,
    PricingContext,
    PromotionDraft,
    StagedChange,
)

from .client import NotFound, Refused, ShopClient


class AppBuilderMerchant(MerchantBackend):
    def __init__(self, client: ShopClient):
        self._client = client

    @staticmethod
    def _headers(session: MerchantSessionContext) -> dict[str, str]:
        return {"X-Agent-Operator": session.operator}

    async def _get(self, session, path: str, **params):
        return await self._client.request("GET", path, headers=self._headers(session), params=params)

    async def _stage(self, session, kind: str, payload: dict[str, Any]) -> StagedChange:
        try:
            body = await self._client.request(
                "POST", "/merchant/changes", headers=self._headers(session), json={"kind": kind, "payload": payload, "actor_kind": "agent"}
            )
        except (Refused, NotFound) as error:
            raise ChangeNotApplicable(str(error)) from error
        return StagedChange.model_validate(body)

    async def get_business_snapshot(self, session, period: str | None = None) -> BusinessSnapshot:
        return BusinessSnapshot.model_validate(await self._get(session, "/merchant/snapshot", **({"period": period} if period else {})))

    async def query_metrics(self, session, metric, period=None, granularity="day", segment=None) -> MetricSeries:
        params = {"metric": metric, "granularity": granularity}
        params |= {key: value for key, value in {"period": period, "segment": segment}.items() if value}
        return MetricSeries.model_validate(await self._get(session, "/merchant/metrics", **params))

    async def get_campaign_performance(self, session, campaign_id=None) -> list[Campaign]:
        body = await self._get(session, "/merchant/campaigns")
        return [Campaign.model_validate(campaign) for campaign in body["campaigns"]]

    async def search_listings(self, session, query, filters: ListingFilters | None = None, limit: int = 8) -> list[Listing]:
        params: dict[str, Any] = {"query": query, "limit": limit}
        if filters:
            params |= {key: value for key, value in filters.model_dump().items() if value is not None and key != "content_quality"}
        body = await self._get(session, "/merchant/listings", **params)
        listings = [Listing.model_validate(listing) for listing in body["listings"]]
        if filters and filters.content_quality:
            listings = [listing for listing in listings if listing.content_quality == filters.content_quality]
        return listings

    async def get_listing(self, session, listing_id) -> ListingDetails | None:
        try:
            return ListingDetails.model_validate(await self._get(session, f"/merchant/listings/{listing_id}"))
        except NotFound:
            return None

    async def get_inventory_alerts(self, session) -> list[InventoryAlert]:
        body = await self._get(session, "/merchant/inventory_alerts")
        return [InventoryAlert.model_validate(alert) for alert in body["alerts"]]

    async def get_order_issues(self, session) -> list[OrderIssue]:
        body = await self._get(session, "/merchant/order_issues")
        return [OrderIssue.model_validate(issue) for issue in body["issues"]]

    async def get_pricing_context(self, session, listing_id) -> PricingContext | None:
        try:
            return PricingContext.model_validate(await self._get(session, f"/merchant/listings/{listing_id}/pricing"))
        except NotFound:
            return None

    async def stage_listing_update(self, session, listing_id, fields, note=None) -> StagedChange:
        return await self._stage(session, "listing_update", {"listing_id": listing_id, "fields": fields, "note": note})

    async def stage_price_update(self, session, items: list[PriceUpdateItem], note=None) -> StagedChange:
        return await self._stage(session, "price_update", {"items": [item.model_dump() for item in items], "note": note})

    async def stage_inventory_action(self, session, items: list[InventoryActionItem], note=None) -> StagedChange:
        return await self._stage(session, "inventory_action", {"items": [item.model_dump() for item in items], "note": note})

    async def stage_promotion(self, session, promotion: PromotionDraft) -> StagedChange:
        return await self._stage(session, "promotion", promotion.model_dump())

    async def stage_campaign(self, session, campaign: CampaignDraft) -> StagedChange:
        raise ChangeNotApplicable("Ad campaigns are run outside the shop; it can't create or change them")

    async def get_pending_changes(self, session) -> list[StagedChange]:
        body = await self._get(session, "/merchant/changes")
        return [StagedChange.model_validate(change) for change in body["changes"]]

    async def apply_change(self, session, change_id) -> StagedChange:
        return await self._transition(session, change_id, "apply", {})

    async def discard_change(self, session, change_id, actor_kind: ActorKind = ActorKind.OPERATOR) -> StagedChange:
        return await self._transition(session, change_id, "discard", {"actor_kind": actor_kind.value})

    async def _transition(self, session, change_id: str, action: str, body: dict[str, Any]) -> StagedChange:
        try:
            result = await self._client.request("POST", f"/merchant/changes/{change_id}/{action}", headers=self._headers(session), json=body)
        except (Refused, NotFound) as error:
            raise ChangeNotApplicable(str(error)) from error
        return StagedChange.model_validate(result)

    async def get_merchant_context(self, session) -> dict[str, Any] | None:
        return await self._get(session, "/merchant/context")
