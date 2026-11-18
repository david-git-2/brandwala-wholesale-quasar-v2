"""CheckFresh batch decode + brand slug resolution."""

from __future__ import annotations

import http.cookiejar
import json
import re
import time
import unicodedata
import urllib.error
import urllib.request
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

CHECKFRESH_BASE = "https://www.checkfresh.com"
DEFAULT_DELAY_SEC = 0.35
PARALLEL_LOOKUPS = 5
BRAND_MAP_PATH = Path(__file__).resolve().parent / "brand_map.json"

NAME_ALIASES = frozenset(
    {"name", "product", "product_name", "product name", "description"}
)
BATCH_ALIASES = frozenset({"batch", "batch_code", "batch code", "lot", "lot code"})

NOT_FOUND_REMAINING = "If more than 18 months then will be accepted"


@dataclass(frozen=True)
class DecodeResult:
    slug: str
    checkfresh_brand: str | None
    production_date: date | None
    age: str | None
    notes: str | None
    error: str | None


def normalize_header(value: str) -> str:
    text = str(value).strip().lower()
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return re.sub(r"_+", "_", text).strip("_")


def load_brand_map() -> dict[str, Any]:
    raw = json.loads(BRAND_MAP_PATH.read_text(encoding="utf-8"))
    prefixes: list[tuple[str, str]] = [
        (str(p[0]).upper(), str(p[1])) for p in raw.get("prefixes", [])
    ]
    prefixes.sort(key=lambda x: len(x[0]), reverse=True)
    slug_overrides = {
        str(k).lower().strip(): str(v) for k, v in (raw.get("slug_overrides") or {}).items()
    }
    return {"prefixes": prefixes, "slug_overrides": slug_overrides}


def ascii_fold(text: str) -> str:
    return (
        unicodedata.normalize("NFKD", text)
        .encode("ascii", "ignore")
        .decode("ascii")
    )


def slugify(brand: str) -> str:
    s = ascii_fold(brand.strip().lower())
    s = s.replace("'", "").replace("’", "")
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def resolve_slug(product_name: str, brand_map: dict[str, Any] | None = None) -> str:
    brand_map = brand_map or load_brand_map()
    upper = product_name.strip().upper()
    for prefix, slug in brand_map["prefixes"]:
        if upper.startswith(prefix):
            return slug
    # first meaningful token as brand hint
    token = product_name.strip().split()[0] if product_name.strip() else ""
    normalized = ascii_fold(token).lower().strip()
    if normalized in brand_map["slug_overrides"]:
        return brand_map["slug_overrides"][normalized]
    guess = slugify(token)
    return brand_map["slug_overrides"].get(guess, guess)


def parse_production_date(raw: str | None) -> date | None:
    if not raw or not str(raw).strip():
        return None
    text = str(raw).strip()
    for fmt in ("%Y-%m-%d", "%Y-%m"):
        try:
            dt = datetime.strptime(text, fmt)
            if fmt == "%Y-%m":
                return date(dt.year, dt.month, 1)
            return dt.date()
        except ValueError:
            continue
    return None


def decode_batch(slug: str, batch: str) -> DecodeResult:
    batch = batch.strip().upper()
    url = f"{CHECKFRESH_BASE}/{slug}.html"
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    headers = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"}

    try:
        with opener.open(urllib.request.Request(url, headers=headers), timeout=30) as resp:
            html = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return DecodeResult(slug, None, None, None, None, f"HTTP {exc.code}")
    except urllib.error.URLError as exc:
        return DecodeResult(slug, None, None, None, None, str(exc.reason))

    if 'name="hash"' not in html:
        return DecodeResult(slug, None, None, None, None, "no decode form on page")

    fields: dict[str, str] = {}
    for name in ("marka_id", "marka", "hash"):
        match = re.search(rf'name="{name}"[^>]*value="([^"]*)"', html)
        if not match:
            return DecodeResult(slug, None, None, None, None, f"missing {name}")
        fields[name] = match.group(1)

    payload = {**fields, "batch": batch}
    req = urllib.request.Request(
        url,
        data=urlencode(payload).encode(),
        headers={**headers, "Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with opener.open(req, timeout=30) as resp:
            result_html = resp.read().decode("utf-8", "replace")
    except urllib.error.URLError as exc:
        return DecodeResult(slug, fields.get("marka"), None, None, None, str(exc.reason))

    block_match = re.search(r'id="results"[^>]*>(.*?)</div>', result_html, re.S)
    block = block_match.group(1) if block_match else ""

    if "session has expired" in block.lower():
        return DecodeResult(slug, fields.get("marka"), None, None, None, "session expired")

    if "invalid data!" in block.lower():
        return DecodeResult(slug, fields.get("marka"), None, None, None, "invalid batch")

    if "we will try to use the information" in block.lower():
        return DecodeResult(slug, fields.get("marka"), None, None, None, "unsupported brand")

    def cell(label: str) -> str | None:
        m = re.search(rf"<td>{re.escape(label)}</td><td>([^<]+)", block)
        return m.group(1).strip() if m else None

    production_raw = cell("Production date")
    prod_date = parse_production_date(production_raw)
    if production_raw and prod_date is None:
        return DecodeResult(
            slug,
            fields.get("marka"),
            None,
            cell("Age"),
            cell("Notes"),
            f"unparsed date: {production_raw}",
        )
    if not prod_date:
        return DecodeResult(slug, fields.get("marka"), None, cell("Age"), cell("Notes"), "no date in response")

    return DecodeResult(
        slug,
        fields.get("marka"),
        prod_date,
        cell("Age"),
        cell("Notes"),
        None,
    )


class DecodeCache:
    def __init__(self, delay_sec: float = DEFAULT_DELAY_SEC) -> None:
        self._cache: dict[tuple[str, str], DecodeResult] = {}
        self._delay_sec = delay_sec
        self._last_call = 0.0

    def has(self, slug: str, batch: str) -> bool:
        return (slug, batch.strip().upper()) in self._cache

    def get(self, slug: str, batch: str) -> DecodeResult:
        key = (slug, batch.strip().upper())
        if key in self._cache:
            return self._cache[key]
        elapsed = time.monotonic() - self._last_call
        if elapsed < self._delay_sec:
            time.sleep(self._delay_sec - elapsed)
        result = decode_batch(slug, batch)
        self._last_call = time.monotonic()
        self._cache[key] = result
        return result

    def prefetch(
        self,
        pairs: list[tuple[str, str]],
        on_result: Callable[[str, str, DecodeResult, int, int], None] | None = None,
        workers: int = PARALLEL_LOOKUPS,
    ) -> None:
        pending: list[tuple[str, str]] = []
        seen: set[tuple[str, str]] = set()
        for slug, batch in pairs:
            key = (slug, batch.strip().upper())
            if key in self._cache or key in seen:
                continue
            seen.add(key)
            pending.append(key)
        if not pending:
            return
        total = len(pending)
        done = 0
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = {
                pool.submit(decode_batch, slug, batch): (slug, batch)
                for slug, batch in pending
            }
            for future in as_completed(futures):
                slug, batch = futures[future]
                result = future.result()
                self._cache[(slug, batch)] = result
                done += 1
                if on_result:
                    on_result(slug, batch, result, done, total)