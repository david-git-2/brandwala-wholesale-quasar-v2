#!/usr/bin/env python3
"""Scrapes elfinternationalltd.com WooCommerce catalog (no login) and writes WTS-shaped JSON."""

import argparse
import html as htmlmod
import json
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import requests

BASE_URL = "https://elfinternationalltd.com/wp-json/wc/store/v1/products"
ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_OUT_JSON = ROOT_DIR / "web" / "public" / "uk" / "elf_data.json"
DEFAULT_OUT_MANIFEST = ROOT_DIR / "web" / "public" / "uk" / "elf_manifest.json"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json",
}

BARCODE_RE = re.compile(r"Barcode\s*:?\s*([0-9]{8,14})", re.IGNORECASE)
CARTON_RE = re.compile(r"Carton\s*Qty\s*:?\s*(\d+)", re.IGNORECASE)
TAG_RE = re.compile(r"<[^>]+>")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape ELF International WooCommerce products.")
    parser.add_argument(
        "--outfile",
        default=str(DEFAULT_OUT_JSON),
        help="Path to output JSON (default: web/public/uk/elf_data.json)",
    )
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_OUT_MANIFEST),
        help="Path to manifest JSON (default: web/public/uk/elf_manifest.json)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit to N products (0 = unlimited)",
    )
    return parser.parse_args()


def strip_html(text: str) -> str:
    if not text:
        return ""
    text = htmlmod.unescape(text)
    text = TAG_RE.sub(" ", text)
    return re.sub(r"\s+", " ", text).strip()


def extract_barcode(description_html: str, product_id: int | str) -> str:
    match = BARCODE_RE.search(description_html or "")
    if match:
        return match.group(1).strip()
    return f"ELF_NO_BARCODE_{product_id}"


def extract_case_size(description_html: str) -> int:
    match = CARTON_RE.search(description_html or "")
    if match:
        try:
            return max(1, int(match.group(1)))
        except ValueError:
            pass
    return 1


def split_brand_category(categories: list[dict[str, Any]]) -> tuple[str, str]:
    brand = ""
    category = ""
    for cat in categories or []:
        name = htmlmod.unescape((cat.get("name") or "").strip())
        link = cat.get("link") or ""
        if not name:
            continue
        if "/product-category/brand/" in link or "/brand/" in link:
            if not brand:
                brand = name
        else:
            if not category:
                category = name
    if not brand and categories:
        brand = htmlmod.unescape((categories[0].get("name") or "").strip())
    return brand, category


def map_product(raw: dict[str, Any]) -> dict[str, Any] | None:
    prod_id = raw.get("id")
    if prod_id is None:
        return None

    description_html = raw.get("description") or ""
    short_html = raw.get("short_description") or ""
    barcode = extract_barcode(description_html, prod_id)
    product_code = f"ELF_{prod_id}"
    product_id = f"{barcode}_{product_code}"

    images = raw.get("images") or []
    image_url = ""
    if isinstance(images, list) and images:
        image_url = images[0].get("src") or ""

    brand, category = split_brand_category(raw.get("categories") or [])
    case_size = extract_case_size(description_html)
    name = htmlmod.unescape((raw.get("name") or "").strip())
    description = strip_html(description_html) or strip_html(short_html)

    return {
        "product_code": product_code,
        "barcode": barcode,
        "product_id": product_id,
        "case_size": case_size,
        "minimum_quantity": case_size,
        "name": name,
        # Prices are login-gated; omit so sync does not overwrite existing list_price.
        "price": None,
        "country_of_origin": "",
        "brand": brand,
        "category": category,
        "available_units": "",
        "inner_case": "",
        "outer_case": "",
        "outer_per_plt": "",
        "tariff_code": "",
        "languages": "",
        "batch_code_manufacture_date": "",
        "sales_unit": "",
        "imageUrl": image_url,
        "expire_date": "",
        "description": description,
        "in_stock": bool(raw.get("is_in_stock", False)),
        "permalink": raw.get("permalink") or "",
        "slug": raw.get("slug") or "",
        "source": "website",
    }


def fetch_all_products(session: requests.Session, limit: int = 0) -> list[dict[str, Any]]:
    print("Fetching page 1 to discover totals...")
    params = {"per_page": 100, "page": 1}
    try:
        r = session.get(BASE_URL, params=params, timeout=30)
        r.raise_for_status()
    except Exception as e:
        raise SystemExit(f"Failed to fetch page 1: {e}")

    total_products = int(r.headers.get("x-wp-total", 0))
    total_pages = int(r.headers.get("x-wp-totalpages", 1))
    print(f"Found {total_products} total products across {total_pages} pages.")

    all_products: list[dict[str, Any]] = list(r.json())

    if limit > 0 and len(all_products) >= limit:
        return all_products[:limit]

    page = 1
    while page < total_pages:
        if limit > 0 and len(all_products) >= limit:
            break
        page += 1
        print(f"Fetching page {page} of {total_pages}...")
        params["page"] = page
        try:
            r = session.get(BASE_URL, params=params, timeout=30)
            if r.status_code == 200:
                all_products.extend(r.json())
            else:
                print(f"Warning: Error fetching page {page}: {r.status_code}")
        except Exception as e:
            print(f"Warning: Connection error on page {page} ({e})")
        time.sleep(0.5)

    if limit > 0:
        return all_products[:limit]
    return all_products


def main() -> None:
    args = parse_args()
    out_json = Path(args.outfile).expanduser().resolve()
    out_manifest = Path(args.manifest).expanduser().resolve()

    session = requests.Session()
    session.headers.update(HEADERS)

    raw_products = fetch_all_products(session, limit=args.limit)
    products: list[dict[str, Any]] = []
    for raw in raw_products:
        mapped = map_product(raw)
        if mapped:
            products.append(mapped)

    now = datetime.now(timezone.utc)
    generated_at = now.isoformat().replace("+00:00", "Z")
    version = now.strftime("%Y%m%d%H%M%S")

    payload = {
        "meta": {
            "generatedAt": generated_at,
            "source": "elfinternationalltd.com",
            "count": len(products),
            "productIdRule": "product_id = barcode + '_ELF_' + id",
        },
        "products": products,
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")

    manifest = {
        "version": version,
        "updated_at": generated_at,
        "count": len(products),
    }
    with open(out_manifest, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"\nSaved {len(products)} products to {out_json}")
    print(f"Manifest: {out_manifest}")


if __name__ == "__main__":
    main()
