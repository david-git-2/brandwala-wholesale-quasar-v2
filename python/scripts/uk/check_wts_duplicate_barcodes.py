#!/usr/bin/env python3
"""Check for duplicate barcodes among WTS products in Supabase."""

from __future__ import annotations

import argparse
import os
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from product_sync_lib import (
    SupabaseRestClient,
    fetch_all_scoped_products_full,
    to_text,
)

WTS_VENDOR_ID = 4


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check for duplicate barcodes in Supabase for WTS products.",
    )
    parser.add_argument(
        "--vendor-id",
        type=int,
        default=WTS_VENDOR_ID,
        help=f"Vendor ID to inspect (default: {WTS_VENDOR_ID}).",
    )
    parser.add_argument(
        "--market",
        dest="market_code",
        default=os.getenv("PY_PRODUCTS_MARKET_CODE", "GB"),
        help="Market code scope (default: GB).",
    )
    parser.add_argument(
        "--parent-tenant-id",
        type=int,
        default=int(os.getenv("PY_PRODUCTS_PARENT_TENANT_ID", "15")),
        help="Warehouse parent tenant ID (default: 15).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    supabase_url = to_text(os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL"))
    supabase_admin_key = to_text(
        os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    )
    if not supabase_url:
        raise ValueError("Missing SUPABASE_URL or VITE_SUPABASE_URL in environment.")
    if not supabase_admin_key:
        raise ValueError("Missing SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY in environment.")

    client = SupabaseRestClient(supabase_url, supabase_admin_key)

    print(
        f"Fetching WTS products for vendor_id={args.vendor_id}, "
        f"market={args.market_code}, parent_tenant_id={args.parent_tenant_id}...",
        flush=True,
    )

    rows = fetch_all_scoped_products_full(
        client,
        vendor_id=args.vendor_id,
        market_code=args.market_code,
        parent_tenant_id=args.parent_tenant_id,
    )

    print(f"Total products found: {len(rows)}\n")

    by_barcode: dict[str, list[dict[str, Any]]] = defaultdict(list)
    empty_barcode_count = 0

    for row in rows:
        raw_barcode = to_text(row.get("barcode"))
        if not raw_barcode:
            empty_barcode_count += 1
            continue
        normalized_barcode = raw_barcode.upper()
        by_barcode[normalized_barcode].append(row)

    duplicates = {b: items for b, items in by_barcode.items() if len(items) > 1}

    if empty_barcode_count > 0:
        print(f"⚠️ Products with empty/null barcode: {empty_barcode_count}")

    if not duplicates:
        print("✅ No duplicate barcodes found! All barcodes are unique.")
        return 0

    print(f"❌ Found {len(duplicates)} duplicate barcode(s):\n")
    print("=" * 80)

    for idx, (barcode, items) in enumerate(duplicates.items(), start=1):
        print(f"{idx}. Barcode: {barcode} ({len(items)} entries)")
        for item in items:
            p_id = item.get("id")
            p_code = item.get("product_code") or "(null)"
            name = item.get("name") or "(no name)"
            price = item.get("list_price_amount")
            is_avail = item.get("is_available")
            avail_units = item.get("available_units")
            has_image = bool(item.get("image_url"))
            print(
                f"   - [ID: {p_id}] Code: {p_code:<15} | Avail: {is_avail} ({avail_units} units) | "
                f"Price: {price} | Image: {has_image} | Name: {name[:50]}"
            )
        print("-" * 80)

    print(f"\nSummary: {len(duplicates)} duplicate barcode groups across {len(rows)} products.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
