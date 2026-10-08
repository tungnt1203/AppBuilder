"""The HTTP client both backends use: the shop's agent API (/agent/v1) with the key for one
role as a bearer token. Errors come back as the exceptions the agents relay."""

from __future__ import annotations

from typing import Any

import httpx


class ShopError(RuntimeError):
    """The shop refused or failed a call in a way the agent should report as temporary."""


class NotFound(LookupError):
    """The id is unknown to the shop."""


class Refused(ValueError):
    """The shop doesn't do this (``not_applicable``), with its reason."""


class Unavailable(ValueError):
    """The item exists but can't be bought now; ``in_stock`` names sibling variants that can."""

    def __init__(self, message: str, in_stock: list[str]):
        super().__init__(message)
        self.in_stock = in_stock


class ShopClient:
    def __init__(self, base_url: str, key: str, *, http: httpx.AsyncClient | None = None, timeout: float = 15.0):
        self.base_url = base_url.rstrip("/") + "/agent/v1"
        self._key = key
        self._http = http or httpx.AsyncClient(timeout=timeout)

    async def request(self, method: str, path: str, *, headers: dict[str, str] | None = None, **kwargs: Any) -> Any:
        response = await self._http.request(
            method,
            f"{self.base_url}{path}",
            headers={"Authorization": f"Bearer {self._key}", "Accept": "application/json", **(headers or {})},
            **kwargs,
        )
        body = _json(response)
        if response.status_code < 400:
            return body
        message = body.get("message", response.reason_phrase) if isinstance(body, dict) else response.reason_phrase
        if response.status_code == 404:
            raise NotFound(message)
        if response.status_code == 409 and body.get("error") == "unavailable":
            raise Unavailable(message, body.get("in_stock", []))
        if response.status_code == 422 and body.get("error") == "not_applicable":
            raise Refused(message)
        raise ShopError(f"{method} {path}: {response.status_code} {message}")

    async def aclose(self) -> None:
        await self._http.aclose()


def _json(response: httpx.Response) -> Any:
    try:
        return response.json()
    except ValueError:
        return {}
