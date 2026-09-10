#!/usr/bin/env python3
"""Sync UK WTS JSON products into Supabase (catalog data only; no image handling)."""

from __future__ import annotations

import argparse
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import timedelta
from pathlib import Path
from typing import Any
from uuid import uuid4

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from product_sync_lib import (
    ROOT_DIR,
    SNAPSHOT_RETENTION_DAYS,
    SupabaseRestClient,
    build_scope_params,
    chunked,
    ensure_lookup_rows_for_new_inserts,
    ensure_market_exists,
    env_int,
    fetch_all_scoped_products_full,
    get_vendor_by_id,
    load_products,
    normalize_nullable_text,
    print_progress,
    resolve_gbp_currency_id,
    run_with_retries,
    to_float_or_none,
    to_int_or_none,
    to_text,
    utc_now,
)

DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "wts_data.json"
WTS_VENDOR_CODE = "WTS"
WTS_VENDOR_ID = 4


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upsert UK WTS products into Supabase by barcode; product_code comes from Excel.",
    )
    parser.add_argument(
        "--input",
        dest="input_path",
        default=str(DEFAULT_INPUT),
        help="Input JSON path (default: web/public/uk/wts_data.json).",
    )
    parser.add_argument(
        "--market",
        dest="market_code",
        default=os.getenv("PY_PRODUCTS_MARKET_CODE", "GB"),
        help="Market code scope (default: PY_PRODUCTS_MARKET_CODE or GB).",
    )
    parser.add_argument(
        "--parent-tenant-id",
        dest="parent_tenant_id",
        default=os.getenv("PY_PRODUCTS_PARENT_TENANT_ID", "15").strip() or "15",
        help="Warehouse parent tenant id (default: 15).",
    )
    parser.add_argument(
        "--tenant-id",
        dest="tenant_id",
        default=os.getenv("PY_PRODUCTS_TENANT_ID", "").strip(),
        help="Who ran the sync (inserted_by_tenant_id). Defaults to parent tenant id.",
    )
    parser.add_argument(
        "--vendor-id",
        dest="vendor_id",
        default=os.getenv("PY_PRODUCTS_VENDOR_ID", str(WTS_VENDOR_ID)).strip() or str(WTS_VENDOR_ID),
        help=f"Vendor id scope (default: {WTS_VENDOR_ID}).",
    )
    parser.add_argument(
        "--chunk-size",
        dest="chunk_size",
        type=int,
        default=int(os.getenv("PY_PRODUCTS_SYNC_CHUNK_SIZE", "250")),
        help="Batch size for inserts (default: 250).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned actions without writing to DB.",
    )
    parser.add_argument(
        "--update-workers",
        dest="update_workers",
        type=int,
        default=env_int("PY_PRODUCTS_UPDATE_WORKERS", 16),
        help="Parallel workers for row updates (default: 16).",
    )
    parser.add_argument(
        "--insert-workers",
        dest="insert_workers",
        type=int,
        default=env_int("PY_PRODUCTS_INSERT_WORKERS", 4),
        help="Parallel workers for insert batches (default: 4).",
    )
    parser.add_argument(
        "--write-retries",
        dest="write_retries",
        type=int,
        default=env_int("PY_PRODUCTS_WRITE_RETRIES", 3),
        help="Retry attempts per write operation (default: 3).",
    )
    return parser.parse_args()


def build_wts_sync_payloads(
    row: dict[str, Any],
    vendor_code: str,
    vendor_id: int,
    market_code: str,
    parent_tenant_id: int,
    inserted_by_tenant_id: int,
    gbp_currency_id: int,
) -> tuple[dict[str, Any], dict[str, Any]] | None:
    barcode = to_text(row.get("barcode"))
    product_code = to_text(row.get("product_code"))
    if not barcode or not product_code:
        return None

    available_units = to_int_or_none(row.get("available_units"))
    minimum_order_quantity = to_int_or_none(row.get("minimum_quantity") or row.get("minimum_order_quantity"))
    if minimum_order_quantity is None:
        minimum_order_quantity = to_int_or_none(row.get("case_size"))
    if minimum_order_quantity is not None and minimum_order_quantity < 1:
        minimum_order_quantity = 1

    price = to_float_or_none(row.get("price"))

    insert_payload: dict[str, Any] = {
        "parent_tenant_id": parent_tenant_id,
        "inserted_by_tenant_id": inserted_by_tenant_id,
        "vendor_id": vendor_id,
        "vendor_code": vendor_code,
        "market_code": market_code,
        "barcode": barcode,
        "product_code": product_code,
        "name": normalize_nullable_text(row.get("name") or row.get("title")),
        "list_price_amount": price,
        "list_price_currency_id": gbp_currency_id if price is not None else None,
        "country_of_origin": normalize_nullable_text(row.get("country_of_origin")),
        "brand": normalize_nullable_text(row.get("brand")),
        "category": normalize_nullable_text(row.get("category")),
        "available_units": available_units,
        "languages": normalize_nullable_text(row.get("languages")),
        "batch_code_manufacture_date": normalize_nullable_text(row.get("batch_code_manufacture_date")),
        "expire_date": normalize_nullable_text(row.get("expire_date")),
        "minimum_order_quantity": minimum_order_quantity,
        "is_available": (available_units > 0) if available_units is not None else None,
        "source": row.get("source") or "excel",
        "hazardous": row.get("hazardous") if row.get("hazardous") is not None else None,
    }

    update_payload: dict[str, Any] = {}
    for key, value in insert_payload.items():
        if key in (
            "parent_tenant_id",
            "inserted_by_tenant_id",
            "vendor_id",
            "vendor_code",
            "market_code",
            "category",
            "barcode",
            "product_code",
        ):
            continue
        if value is not None:
            update_payload[key] = value

    return insert_payload, update_payload


def pick_best_barcode_match(matches: list[dict[str, Any]]) -> dict[str, Any]:
    with_image = [row for row in matches if normalize_nullable_text(row.get("image_url"))]
    if len(with_image) == 1:
        return with_image[0]
    if len(with_image) > 1:
        website = [
            row
            for row in with_image
            if to_text(row.get("source")).lower() in ("website", "web")
        ]
        return website[0] if website else with_image[0]

    website = [
        row for row in matches if to_text(row.get("source")).lower() in ("website", "web")
    ]
    if website:
        return website[0]
    return matches[0]


def resolve_existing_items_by_barcode(
    barcode: str,
    excel_product_code: str,
    existing_by_barcode: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    matches = existing_by_barcode.get(barcode, [])
    if not matches:
        return []

    excel_code_upper = excel_product_code.upper()
    code_matches = [
        row for row in matches if to_text(row.get("product_code")).upper() == excel_code_upper
    ]
    if code_matches:
        return [pick_best_barcode_match(code_matches)]

    return [pick_best_barcode_match(matches)]


def find_image_url_for_barcode(
    barcode: str,
    existing_rows_full: list[dict[str, Any]],
    *,
    exclude_id: int | None = None,
) -> str | None:
    for row in existing_rows_full:
        if to_text(row.get("barcode")).upper() != barcode:
            continue
        row_id = row.get("id")
        if exclude_id is not None and row_id == exclude_id:
            continue
        image_url = normalize_nullable_text(row.get("image_url"))
        if image_url:
            return image_url
    return None


def build_wts_update_payload(
    existing_item: dict[str, Any],
    update_payload: dict[str, Any],
    insert_payload: dict[str, Any],
    existing_rows_full: list[dict[str, Any]],
) -> dict[str, Any]:
    final_update_payload = dict(update_payload)
    final_update_payload.pop("image_url", None)

    db_source = to_text(existing_item.get("source")).lower()
    if db_source in ("website", "web"):
        final_update_payload.pop("source", None)

    excel_product_code = to_text(insert_payload.get("product_code"))
    if excel_product_code:
        final_update_payload["product_code"] = excel_product_code

    row_id = existing_item.get("id")
    if not normalize_nullable_text(existing_item.get("image_url")):
        donor_url = find_image_url_for_barcode(
            to_text(existing_item.get("barcode")).upper(),
            existing_rows_full,
            exclude_id=int(row_id) if row_id is not None else None,
        )
        if donor_url:
            final_update_payload["image_url"] = donor_url

    return final_update_payload


def main() -> int:
    args = parse_args()

    parent_raw = to_text(args.parent_tenant_id) or "15"
    if not (parent_raw.isdigit() and int(parent_raw) > 0):
        raise SystemExit("parent tenant id must be a positive integer (default 15).")
    parent_tenant_id = int(parent_raw)
    inserted_raw = to_text(args.tenant_id)
    inserted_by_tenant_id = (
        int(inserted_raw) if inserted_raw.isdigit() and int(inserted_raw) > 0 else parent_tenant_id
    )
    print(
        f"Using parent_tenant_id={parent_tenant_id}, "
        f"inserted_by_tenant_id={inserted_by_tenant_id}",
        flush=True,
    )

    input_path = Path(args.input_path).expanduser().resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"Input JSON not found: {input_path}")

    market_code = to_text(args.market_code).upper()
    if not market_code:
        raise ValueError("Market code cannot be empty.")

    supabase_url = to_text(os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL"))
    supabase_admin_key = to_text(
        os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    )
    if not supabase_url:
        raise ValueError("Missing SUPABASE_URL or VITE_SUPABASE_URL in env.")
    if not supabase_admin_key:
        raise ValueError(
            "Missing SUPABASE_SECRET_KEY (preferred) or SUPABASE_SERVICE_ROLE_KEY (legacy) in env."
        )

    client = SupabaseRestClient(supabase_url, supabase_admin_key)
    ensure_market_exists(client, market_code)
    gbp_currency_id = resolve_gbp_currency_id(client)

    resolved_vendor_id = int(args.vendor_id)
    vendor_row = get_vendor_by_id(client, resolved_vendor_id)
    resolved_vendor_code = to_text(vendor_row.get("code")).upper() or WTS_VENDOR_CODE

    vendor_market_code = to_text(vendor_row.get("market_code")).upper()
    if vendor_market_code and vendor_market_code != market_code:
        raise ValueError(
            f"Vendor id {resolved_vendor_id} market mismatch. "
            f"Vendor market={vendor_market_code}, input market={market_code}."
        )

    rows = load_products(input_path)
    barcode_counts: dict[str, int] = {}
    deduped_inserts: dict[str, dict[str, Any]] = {}
    deduped_updates: dict[str, dict[str, Any]] = {}
    skipped_missing_key = 0
    for row in rows:
        payloads = build_wts_sync_payloads(
            row,
            resolved_vendor_code,
            resolved_vendor_id,
            market_code,
            parent_tenant_id,
            inserted_by_tenant_id,
            gbp_currency_id,
        )
        if payloads is None:
            skipped_missing_key += 1
            continue
        insert_payload, update_payload = payloads
        barcode_key = to_text(insert_payload["barcode"]).upper()
        barcode_counts[barcode_key] = barcode_counts.get(barcode_key, 0) + 1
        deduped_inserts[barcode_key] = insert_payload
        deduped_updates[barcode_key] = update_payload

    existing_rows_full = fetch_all_scoped_products_full(
        client, resolved_vendor_id, market_code, parent_tenant_id
    )
    existing_rows = [
        {
            "id": item.get("id"),
            "barcode": item.get("barcode"),
            "product_code": item.get("product_code"),
        }
        for item in existing_rows_full
    ]
    existing_by_barcode: dict[str, list[dict[str, Any]]] = {}
    for item in existing_rows_full:
        barcode_key = to_text(item.get("barcode")).upper()
        if not barcode_key:
            continue
        existing_by_barcode.setdefault(barcode_key, []).append(item)

    updates: list[tuple[int, dict[str, Any]]] = []
    inserts: list[dict[str, Any]] = []

    for barcode_key, insert_payload in deduped_inserts.items():
        excel_product_code = to_text(insert_payload.get("product_code"))
        existing_items = resolve_existing_items_by_barcode(
            barcode_key,
            excel_product_code,
            existing_by_barcode,
        )

        is_available = True

        if existing_items:
            update_payload = dict(deduped_updates.get(barcode_key, {}))
            update_payload["source"] = insert_payload.get("source") or "excel"
            update_payload["hazardous"] = insert_payload.get("hazardous")
            update_payload["is_available"] = is_available

            for existing_item in existing_items:
                row_id = existing_item["id"]
                final_update_payload = build_wts_update_payload(
                    existing_item,
                    update_payload,
                    insert_payload,
                    existing_rows_full,
                )
                updates.append((row_id, final_update_payload))
        else:
            insert_payload["parent_tenant_id"] = parent_tenant_id
            insert_payload["inserted_by_tenant_id"] = inserted_by_tenant_id
            insert_payload["vendor_id"] = resolved_vendor_id
            insert_payload["vendor_code"] = resolved_vendor_code
            insert_payload["is_available"] = is_available
            donor_url = find_image_url_for_barcode(barcode_key, existing_rows_full)
            if donor_url:
                insert_payload["image_url"] = donor_url
            inserts.append(insert_payload)

    scope_params = build_scope_params(resolved_vendor_id, market_code, parent_tenant_id)

    print(f"Input rows: {len(rows)}")
    print(f"Deduped rows: {len(deduped_inserts)}")
    duplicate_input_barcodes = sum(1 for count in barcode_counts.values() if count > 1)
    print(f"Duplicate barcodes in input (last row wins): {duplicate_input_barcodes}")
    print("Match key: barcode only; product_code is always taken from Excel on update.")
    print(f"Skipped missing barcode/product_code: {skipped_missing_key}")
    print(f"Existing scoped products: {len(existing_rows)}")
    print(f"Planned scope reset (is_available=false, hazardous=false): {len(existing_rows)}")
    print(f"Planned updates: {len(updates)}")
    print(f"Planned inserts: {len(inserts)}")
    print(
        "Scope: "
        f"vendor_code={resolved_vendor_code} vendor_id={resolved_vendor_id} "
        f"market={market_code} "
        f"parent_tenant_id={parent_tenant_id} "
        f"inserted_by_tenant_id={inserted_by_tenant_id}"
    )
    print("Image handling: preserve existing DB image_url; Excel input never supplies images.")
    print(
        "Parallel workers: "
        f"update={max(1, args.update_workers)}, "
        f"insert={max(1, args.insert_workers)} | "
        f"write_retries={max(1, args.write_retries)}"
    )

    if args.dry_run:
        ensure_lookup_rows_for_new_inserts(
            client=client,
            vendor_id=resolved_vendor_id,
            vendor_code=resolved_vendor_code,
            inserts=inserts,
            chunk_size=max(1, args.chunk_size),
            dry_run=True,
            write_retries=max(1, args.write_retries),
        )
        print("Dry run complete. No DB writes.")
        return 0

    snapshot_now = utc_now()
    snapshot_run_id = f"{snapshot_now.strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:10]}"
    snapshot_expires_at = snapshot_now + timedelta(days=SNAPSHOT_RETENTION_DAYS)
    snapshot_rows = []
    for row in existing_rows_full:
        product_id = row.get("id")
        if product_id is None:
            continue
        snapshot_rows.append(
            {
                "run_id": snapshot_run_id,
                "captured_at": snapshot_now.isoformat(),
                "expires_at": snapshot_expires_at.isoformat(),
                "tenant_id": parent_tenant_id,
                "vendor_id": row.get("vendor_id"),
                "vendor_code": resolved_vendor_code,
                "market_code": market_code,
                "product_id": int(product_id),
                "barcode": to_text(row.get("barcode")) or None,
                "product_code": to_text(row.get("product_code")) or None,
                "row_data": row,
            }
        )

    print(
        f"Snapshot run: {snapshot_run_id} | rows={len(snapshot_rows)} | retention={SNAPSHOT_RETENTION_DAYS} days",
        flush=True,
    )
    print("Cleaning expired snapshots...", flush=True)
    run_with_retries(
        lambda: client.delete_rows(
            "product_sync_snapshots",
            {"expires_at": f"lt.{snapshot_now.isoformat()}"},
        ),
        retries=max(1, args.write_retries),
    )
    print("Expired snapshot cleanup complete.", flush=True)

    if snapshot_rows:
        print("Writing pre-sync snapshot rows...", flush=True)
        snapshot_batches = chunked(snapshot_rows, max(1, args.chunk_size))
        snapshot_total = len(snapshot_batches)
        snapshot_start = time.perf_counter()
        snapshot_failures = 0
        for idx, batch in enumerate(snapshot_batches, start=1):
            try:
                run_with_retries(
                    lambda b=batch: client.insert_rows("product_sync_snapshots", b),
                    retries=max(1, args.write_retries),
                )
            except Exception as exc:
                snapshot_failures += 1
                print(f"Snapshot batch failed: {exc}", flush=True)
            if idx % 5 == 0 or idx == snapshot_total:
                print_progress("Snapshot batches", idx, snapshot_total, snapshot_start)

        if snapshot_failures > 0:
            raise RuntimeError(
                f"Snapshot failed for {snapshot_failures} batch(es). Sync aborted to keep rollback safety."
            )

    print("Applying scope reset (is_available=false, hazardous=false)...", flush=True)
    client.update_rows("products", scope_params, {"is_available": False, "hazardous": False})
    print("Scope reset complete.", flush=True)

    ensure_lookup_rows_for_new_inserts(
        client=client,
        vendor_id=resolved_vendor_id,
        vendor_code=resolved_vendor_code,
        inserts=inserts,
        chunk_size=max(1, args.chunk_size),
        dry_run=False,
        write_retries=max(1, args.write_retries),
    )

    updates_total = len(updates)
    updates_start = time.perf_counter()
    update_failures = 0
    if updates_total > 0:
        print("Applying row updates...", flush=True)

    def run_update(row_id: int, payload: dict[str, Any]) -> None:
        run_with_retries(
            lambda: client.update_row_by_id("products", row_id, payload),
            retries=max(1, args.write_retries),
        )

    if updates_total > 0:
        with ThreadPoolExecutor(max_workers=max(1, args.update_workers)) as executor:
            futures = [executor.submit(run_update, row_id, payload) for row_id, payload in updates]
            done = 0
            for future in as_completed(futures):
                done += 1
                try:
                    future.result()
                except Exception as exc:
                    update_failures += 1
                    print(f"Update failed: {exc}", flush=True)
                if done % 25 == 0 or done == updates_total:
                    print_progress("Updates", done, updates_total, updates_start)

    insert_batches = chunked(inserts, max(1, args.chunk_size))
    batch_total = len(insert_batches)
    batch_start = time.perf_counter()
    insert_failures = 0
    if batch_total > 0:
        print("Applying inserts...", flush=True)

    def run_insert_batch(batch: list[dict[str, Any]]) -> None:
        run_with_retries(
            lambda: client.insert_rows("products", batch),
            retries=max(1, args.write_retries),
        )

    if batch_total > 0:
        with ThreadPoolExecutor(max_workers=max(1, args.insert_workers)) as executor:
            futures = [executor.submit(run_insert_batch, batch) for batch in insert_batches]
            done = 0
            for future in as_completed(futures):
                done += 1
                try:
                    future.result()
                except Exception as exc:
                    insert_failures += 1
                    print(f"Insert batch failed: {exc}", flush=True)
                if done % 5 == 0 or done == batch_total:
                    print_progress("Insert batches", done, batch_total, batch_start)

    print(
        "Write summary: "
        f"update_failures={update_failures}, insert_failures={insert_failures}",
        flush=True,
    )
    print("Sync complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
