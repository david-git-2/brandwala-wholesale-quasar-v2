#!/usr/bin/env python3
"""Scrape Lavishta (lavishta.com) WooCommerce catalog and export low-stock rows to CSV."""

from __future__ import annotations

import argparse
import csv
import html
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

BASE_URL = "https://lavishta.com/wp-json/wc/store/v1/products"
ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_OUTFILE = ROOT_DIR / "web" / "public" / "bd" / "lavishta_low_stock.csv"

CSV_FIELDS = [
    "source_id",
    "sku",
    "name",
    "brand",
    "category",
    "price_bdt",
    "regular_price_bdt",
    "sale_price_bdt",
    "on_sale",
    "qty_remaining",
    "stock_text",
    "in_stock",
    "product_type",
    "permalink",
    "scraped_at",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scrape Lavishta products and write low-stock (or full catalog) CSV.",
    )
    parser.add_argument(
        "--outfile",
        default=str(DEFAULT_OUTFILE),
        help=f"Output CSV path (default: {DEFAULT_OUTFILE.relative_to(ROOT_DIR)})",
    )
    parser.add_argument(
        "--max-qty",
        type=int,
        default=5,
        help="Include in-stock items with qty_remaining at or below this (default: 5)",
    )
    parser.add_argument(
        "--include-out-of-stock",
        action="store_true",
        help="Also include items that are out of stock (qty 0)",
    )
    parser.add_argument(
        "--all-products",
        action="store_true",
        help="Export every product instead of filtering to low / scarce stock",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Stop after N products fetched (0 = no limit; for testing)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.75,
        help="Seconds to wait between page requests (default: 0.75)",
    )
    return parser.parse_args()


def make_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"
            ),
            "Accept": "application/json",
        }
    )
    return session


def fetch_page(session: requests.Session, page: int, per_page: int = 100) -> requests.Response:
    params = {"per_page": per_page, "page": page}
    last_err: Exception | None = None
    for attempt in range(4):
        try:
            resp = session.get(BASE_URL, params=params, timeout=60)
            if resp.status_code in (403, 429, 502, 503):
                wait = 2 ** attempt
                print(f"HTTP {resp.status_code} on page {page}, retry in {wait}s...")
                time.sleep(wait)
                continue
            resp.raise_for_status()
            return resp
        except requests.RequestException as exc:
            last_err = exc
            wait = 2 ** attempt
            print(f"Request error on page {page} ({exc}), retry in {wait}s...")
            time.sleep(wait)
    raise SystemExit(f"Failed to fetch page {page}: {last_err}")


def fetch_all_products(session: requests.Session, limit: int, delay: float) -> list[dict[str, Any]]:
    print("Fetching page 1...")
    first = fetch_page(session, 1)
    total = int(first.headers.get("x-wp-total", 0))
    total_pages = int(first.headers.get("x-wp-totalpages", 1))
    print(f"Catalog: {total} products, {total_pages} pages")

    products: list[dict[str, Any]] = list(first.json())
    if limit > 0 and len(products) >= limit:
        return products[:limit]

    page = 1
    while page < total_pages:
        if limit > 0 and len(products) >= limit:
            break
        page += 1
        print(f"Fetching page {page}/{total_pages}...")
        time.sleep(delay)
        resp = fetch_page(session, page)
        batch = resp.json()
        if not batch:
            break
        products.extend(batch)
        if limit > 0 and len(products) >= limit:
            products = products[:limit]
            break

    return products


def first_name(items: list[dict[str, Any]] | None, key: str = "name") -> str:
    if not items:
        return ""
    return html.unescape(str(items[0].get(key) or ""))


def qty_from_product(product: dict[str, Any]) -> int | None:
    low = product.get("low_stock_remaining")
    if low is not None and low != "":
        try:
            return int(low)
        except (TypeError, ValueError):
            pass

    text = str((product.get("stock_availability") or {}).get("text") or "")
    match = re.search(r"only\s+(\d+)\s+left", text, re.IGNORECASE)
    if match:
        return int(match.group(1))

    add = product.get("add_to_cart") or {}
    maximum = add.get("maximum")
    text_lower = text.lower()
    if (
        product.get("is_in_stock")
        and maximum is not None
        and maximum != 9999
        and "only" in text_lower
    ):
        try:
            return int(maximum)
        except (TypeError, ValueError):
            pass

    if not product.get("is_in_stock"):
        return 0

    return None


def is_low_stock_row(
    product: dict[str, Any],
    max_qty: int,
    include_out_of_stock: bool,
) -> bool:
    in_stock = bool(product.get("is_in_stock"))
    qty = qty_from_product(product)
    text = str((product.get("stock_availability") or {}).get("text") or "")

    if not in_stock:
        return include_out_of_stock

    if qty is not None and qty <= max_qty:
        return True

    if re.search(r"only\s+\d+\s+left", text, re.IGNORECASE):
        return True

    return False


def product_to_row(product: dict[str, Any], scraped_at: str) -> dict[str, str]:
    prices = product.get("prices") or {}
    qty = qty_from_product(product)
    return {
        "source_id": str(product.get("id") or ""),
        "sku": str(product.get("sku") or ""),
        "name": html.unescape(str(product.get("name") or "")),
        "brand": first_name(product.get("brands")),
        "category": first_name(product.get("categories")),
        "price_bdt": str(prices.get("price") or ""),
        "regular_price_bdt": str(prices.get("regular_price") or ""),
        "sale_price_bdt": str(prices.get("sale_price") or ""),
        "on_sale": "yes" if product.get("on_sale") else "no",
        "qty_remaining": "" if qty is None else str(qty),
        "stock_text": str((product.get("stock_availability") or {}).get("text") or ""),
        "in_stock": "yes" if product.get("is_in_stock") else "no",
        "product_type": str(product.get("type") or ""),
        "permalink": str(product.get("permalink") or ""),
        "scraped_at": scraped_at,
    }


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    outfile = Path(args.outfile).expanduser().resolve()
    scraped_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    session = make_session()
    products = fetch_all_products(session, args.limit, args.delay)

    if args.all_products:
        selected = products
    else:
        selected = [
            p
            for p in products
            if is_low_stock_row(p, args.max_qty, args.include_out_of_stock)
        ]
        selected.sort(
            key=lambda p: (
                qty_from_product(p) if qty_from_product(p) is not None else 99999,
                html.unescape(str(p.get("name") or "")),
            ),
        )

    rows = [product_to_row(p, scraped_at) for p in selected]
    write_csv(outfile, rows)

    mode = "all products" if args.all_products else "low-stock filter"
    print(f"\nFetched {len(products)} products; wrote {len(rows)} rows ({mode}) to:")
    print(outfile)


if __name__ == "__main__":
    main()
