#!/usr/bin/env python3
"""Sync UK PC JSON products into Supabase products table."""

from __future__ import annotations

import argparse
import mimetypes
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import timedelta
from pathlib import Path
from typing import Any
from uuid import uuid4

try:
    import requests
except ModuleNotFoundError:  # pragma: no cover - handled at runtime
    requests = None  # type: ignore[assignment]

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from product_sync_lib import (
    ROOT_DIR,
    SNAPSHOT_RETENTION_DAYS,
    WEB_ENV_FILE,
    ROOT_ENV_FILE,
    SupabaseRestClient,
    assert_vendor_parent_scope,
    build_scope_params,
    chunked,
    ensure_lookup_rows_for_new_inserts,
    ensure_market_exists,
    ensure_vendor_exists,
    env_int,
    fetch_all_scoped_products_full,
    get_vendor_by_id,
    load_env_file,
    load_products,
    normalize_nullable_text,
    print_progress,
    product_key,
    resolve_gbp_currency_id,
    run_with_retries,
    to_float_or_none,
    to_int_or_none,
    to_text,
    utc_now,
)

DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.json"
DEFAULT_STORAGE_BUCKET = str(os.getenv("PY_SUPABASE_STORAGE_BUCKET") or "product-images").strip()
DEFAULT_STORAGE_PREFIX = str(os.getenv("PY_SUPABASE_STORAGE_PREFIX") or "uk/pc").strip().strip("/")
DEFAULT_IMAGES_DIR = ROOT_DIR / "python" / "images" / "uk" / "out_images"
PC_VENDOR_CODE = "PC"
PC_VENDOR_ID = 3


def switch_web_env_to_prod() -> None:
    script = ROOT_DIR / "scripts" / "env-switch.sh"
    print("Switching web/.env to prod...", flush=True)
    subprocess.run(["bash", str(script), "prod"], check=True, cwd=str(ROOT_DIR))
    load_env_file(WEB_ENV_FILE, overwrite=True)
    load_env_file(ROOT_ENV_FILE, overwrite=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upsert UK PC products into Supabase by barcode+product_code.",
    )
    parser.add_argument(
        "--input",
        dest="input_path",
        default=str(DEFAULT_INPUT),
        help="Input JSON path (default: web/public/uk/pc_data.json)",
    )
    parser.add_argument(
        "--vendor",
        dest="vendor_code",
        default=os.getenv("PY_PRODUCTS_VENDOR_CODE", "PC"),
        help="Vendor code scope (default: PY_PRODUCTS_VENDOR_CODE or PC).",
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
        help="Optional. Who ran the sync (inserted_by_tenant_id). Defaults to parent tenant id.",
    )
    parser.add_argument(
        "--vendor-id",
        dest="vendor_id",
        default=os.getenv("PY_PRODUCTS_VENDOR_ID", "").strip(),
        help="Vendor id scope. Overrides default vendor code resolution if provided.",
    )
    parser.add_argument(
        "--skip-image-upload",
        action="store_true",
        help="Skip local image upload phase and use image URLs from JSON.",
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
        "--images-dir",
        dest="images_dir",
        default=str(
            Path(
                os.getenv("PY_UK_PC_OUT_IMAGES_DIR", str(DEFAULT_IMAGES_DIR))
            ).expanduser()
        ),
        help="Directory of local extracted images (default: PY_UK_PC_OUT_IMAGES_DIR or python/images/uk/out_images).",
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
        "--image-workers",
        dest="image_workers",
        type=int,
        default=env_int("PY_PRODUCTS_IMAGE_WORKERS", 20),
        help="Parallel workers for image upload+image_url update (default: 20).",
    )
    parser.add_argument(
        "--write-retries",
        dest="write_retries",
        type=int,
        default=env_int("PY_PRODUCTS_WRITE_RETRIES", 3),
        help="Retry attempts per write operation (default: 3).",
    )
    return parser.parse_args()


def build_image_key(row: dict[str, Any], barcode: str, product_code: str) -> str:
    explicit_key = to_text(row.get("imageKey") or row.get("image_key"))
    if explicit_key:
        return explicit_key
    return f"{barcode}__{product_code}"


def build_storage_object_path(prefix: str, file_name: str) -> str:
    clean_file_name = to_text(file_name)
    if not clean_file_name:
        raise ValueError("Storage file name cannot be empty.")
    if "/" in clean_file_name:
        raise ValueError("Storage file name must not contain '/'.")
    file_name = clean_file_name
    return f"{prefix}/{file_name}" if prefix else file_name


def build_public_storage_url(base_url: str, bucket: str, object_path: str) -> str:
    base = base_url.rstrip("/")
    return f"{base}/storage/v1/object/public/{bucket}/{object_path}"


def upload_to_supabase_storage(
    supabase_url: str,
    api_key: str,
    bucket: str,
    object_path: str,
    local_path: Path,
    content_type: str = "application/octet-stream",
) -> str:
    if requests is None:
        raise RuntimeError("Missing Python dependency: requests")
    base = supabase_url.rstrip("/")
    url = f"{base}/storage/v1/object/{bucket}/{object_path}"
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {api_key}",
        "x-upsert": "true",
        "Content-Type": content_type,
    }
    with local_path.open("rb") as f:
        resp = requests.post(url, headers=headers, data=f, timeout=120)
    if not resp.ok:
        raise RuntimeError(f"supabase upload failed ({resp.status_code}): {resp.text}")
    return build_public_storage_url(base, bucket, object_path)


def build_sync_payloads(
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

    # Insert payload can include null-capable values for new rows.
    image_url = row.get("imageUrl") or row.get("image_url") or row.get("original_image_url") or row.get("image")
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
        "image_url": normalize_nullable_text(image_url),
        "source": row.get("source") or "excel",
        "hazardous": row.get("hazardous") if row.get("hazardous") is not None else None,
    }

    # Update payload is PATCH-style: only write fields with concrete values,
    # so existing DB values (e.g. prefilled product_weight/package_weight) stay untouched.
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


def chunked_ids(items: list[int], size: int) -> list[list[int]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def apply_scope_reset(
    client: SupabaseRestClient,
    scope_params: dict[str, Any],
    product_ids: list[int],
    chunk_size: int,
    write_retries: int,
) -> None:
    payload = {"is_available": False, "hazardous": False}
    if not product_ids:
        print("Scope reset skipped (no existing scoped products).", flush=True)
        return
    batches = chunked_ids(product_ids, max(1, chunk_size))
    start = time.perf_counter()
    total = len(batches)
    print(
        f"Applying scope reset in {total} batch(es) of up to {max(1, chunk_size)}...",
        flush=True,
    )
    for idx, batch in enumerate(batches, start=1):
        params = dict(scope_params)
        params["id"] = f"in.({','.join(str(item_id) for item_id in batch)})"
        run_with_retries(
            lambda p=params: client.update_rows("products", p, payload),
            retries=max(1, write_retries),
        )
        if idx % 5 == 0 or idx == total:
            print_progress("Scope reset batches", idx, total, start)


def index_local_images_by_key(images_dir: Path) -> dict[str, Path]:
    indexed: dict[str, Path] = {}
    if not images_dir.exists():
        return indexed
    for path in images_dir.iterdir():
        if not path.is_file():
            continue
        stem = path.stem.strip().lower()
        if not stem:
            continue
        indexed[stem] = path
    return indexed


def guess_content_type(path: Path) -> str:
    guessed, _ = mimetypes.guess_type(path.name)
    return guessed or "application/octet-stream"


def main() -> int:
    args = parse_args()
    switch_web_env_to_prod()

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

    vendor_code = to_text(args.vendor_code).upper()
    market_code = to_text(args.market_code).upper()
    if not vendor_code:
        raise ValueError("Vendor code cannot be empty.")
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
    storage_bucket = to_text(os.getenv("PY_SUPABASE_STORAGE_BUCKET") or DEFAULT_STORAGE_BUCKET)
    storage_prefix = to_text(os.getenv("PY_SUPABASE_STORAGE_PREFIX") or DEFAULT_STORAGE_PREFIX).strip("/")
    images_dir = Path(args.images_dir).expanduser().resolve()

    client = SupabaseRestClient(supabase_url, supabase_admin_key)
    ensure_market_exists(client, market_code)

    gbp_currency_id = resolve_gbp_currency_id(client)

    if args.vendor_id and str(args.vendor_id).strip():
        resolved_vendor_id = int(args.vendor_id)
        vendor_row = get_vendor_by_id(client, resolved_vendor_id)
    elif vendor_code == PC_VENDOR_CODE:
        vendor_row = get_vendor_by_id(client, PC_VENDOR_ID)
        resolved_vendor_id = PC_VENDOR_ID
    else:
        vendor_row = ensure_vendor_exists(
            client, vendor_code, market_code, parent_tenant_id, args.dry_run
        )
        resolved_vendor_id = vendor_row["id"]

    resolved_vendor_code = to_text(vendor_row.get("code")).upper() or vendor_code

    vendor_market_code = to_text(vendor_row.get("market_code")).upper()
    if vendor_market_code and vendor_market_code != market_code:
        raise ValueError(
            f"Vendor id {resolved_vendor_id} market mismatch. "
            f"Vendor market={vendor_market_code}, input market={market_code}."
        )

    if int(resolved_vendor_id) > 0:
        assert_vendor_parent_scope(vendor_row, parent_tenant_id, int(resolved_vendor_id))

    rows = load_products(input_path)
    key_counts: dict[tuple[str, str], int] = {}
    deduped_inserts: dict[tuple[str, str], dict[str, Any]] = {}
    deduped_updates: dict[tuple[str, str], dict[str, Any]] = {}
    skipped_missing_key = 0
    for row in rows:
        payloads = build_sync_payloads(
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
        key = (to_text(insert_payload["barcode"]).upper(), to_text(insert_payload["product_code"]).upper())
        key_counts[key] = key_counts.get(key, 0) + 1
        deduped_inserts[key] = insert_payload
        deduped_updates[key] = update_payload

    scope_params = build_scope_params(resolved_vendor_id, market_code, parent_tenant_id)
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
    existing_by_key: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for item in existing_rows_full:
        key = (to_text(item.get("barcode")).upper(), to_text(item.get("product_code")).upper())
        if not key[0]:
            continue
        existing_by_key.setdefault(key, []).append(item)

    updates: list[tuple[int, dict[str, Any]]] = []
    inserts: list[dict[str, Any]] = []
    newly_inserted_keys: set[tuple[str, str]] = set()
    existing_excel_needs_image: set[tuple[int, tuple[str, str]]] = set()

    for key, insert_payload in deduped_inserts.items():
        existing_items = existing_by_key.get(key, [])
        if not existing_items:
            # Fallback: check if there is an existing row with the same barcode but empty/null product_code
            fallback_key = (key[0], "")
            existing_items = existing_by_key.get(fallback_key, [])

        is_available = True

        if existing_items:
            update_payload = dict(deduped_updates.get(key, {}))
            update_payload["source"] = insert_payload.get("source") or "excel"
            update_payload["hazardous"] = insert_payload.get("hazardous")
            update_payload["is_available"] = is_available
            
            for existing_item in existing_items:
                row_id = existing_item["id"]
                db_source = to_text(existing_item.get("source")).lower()
                db_image_url = existing_item.get("image_url")
                db_product_code = to_text(existing_item.get("product_code"))
                
                final_update_payload = dict(update_payload)
                
                # If the DB has no product_code, backfill it
                if not db_product_code:
                    final_update_payload["product_code"] = insert_payload["product_code"]
                
                if db_source in ("website", "web"):
                    # Check the DB if the data is present and the source is website,
                    # then don't update the image url but update the rest data.
                    if "image_url" in final_update_payload:
                        del final_update_payload["image_url"]
                    updates.append((row_id, final_update_payload))
                else:
                    # Excel source: keep existing image_url; upload only when missing.
                    if "image_url" in final_update_payload:
                        del final_update_payload["image_url"]
                    updates.append((row_id, final_update_payload))
                    if not normalize_nullable_text(db_image_url):
                        existing_excel_needs_image.add((row_id, key))
        else:
            insert_payload["parent_tenant_id"] = parent_tenant_id
            insert_payload["inserted_by_tenant_id"] = inserted_by_tenant_id
            insert_payload["vendor_id"] = resolved_vendor_id
            insert_payload["vendor_code"] = resolved_vendor_code
            insert_payload["is_available"] = is_available
            inserts.append(insert_payload)
            newly_inserted_keys.add(key)

    print(f"Input rows: {len(rows)}")
    print(f"Deduped rows: {len(deduped_inserts)}")
    duplicate_input_keys = sum(1 for count in key_counts.values() if count > 1)
    print(f"Duplicate barcode+product_code keys in input: {duplicate_input_keys}")
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
    print(f"Image upload phase: local_dir={images_dir}")
    print(f"Image URL source: backend storage path ({storage_bucket}/{storage_prefix}/<product_id><ext>)")
    print(
        "Parallel workers: "
        f"update={max(1, args.update_workers)}, "
        f"insert={max(1, args.insert_workers)}, "
        f"image={max(1, args.image_workers)} | "
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
            parent_tenant_id=parent_tenant_id,
        )
        print("Dry run complete. No DB writes.")
        return 0

    # Snapshot pre-sync state for rollback and keep only 7 days.
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

    # Scope reset:
    # 1) Mark every scoped product unavailable and non-hazardous.
    # 2) Products in current JSON are updated/inserted with is_available=true
    #    and hazardous=true only when marked yes in Excel.
    print("Applying scope reset (is_available=false, hazardous=false)...", flush=True)
    reset_ids = [int(item["id"]) for item in existing_rows if item.get("id") is not None]
    apply_scope_reset(
        client=client,
        scope_params=scope_params,
        product_ids=reset_ids,
        chunk_size=max(1, args.chunk_size),
        write_retries=max(1, args.write_retries),
    )
    print("Scope reset complete.", flush=True)

    ensure_lookup_rows_for_new_inserts(
        client=client,
        vendor_id=resolved_vendor_id,
        vendor_code=resolved_vendor_code,
        inserts=inserts,
        chunk_size=max(1, args.chunk_size),
        dry_run=False,
        write_retries=max(1, args.write_retries),
        parent_tenant_id=parent_tenant_id,
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

    image_uploaded = 0
    image_failed = 0
    missing_image_keys = 0
    ambiguous_db_keys = 0

    if args.skip_image_upload:
        print("Skipping image upload phase (using image URLs from JSON).", flush=True)
    else:
        # Phase 2: upload images by real DB product id and then update image_url.
        print("Starting image upload phase...", flush=True)
        local_images = index_local_images_by_key(images_dir)
        if not local_images:
            print(f"No local images found in: {images_dir}", flush=True)

        rows_after_sync: list[dict[str, Any]] = []
        offset = 0
        limit = 1000
        while True:
            params: dict[str, Any] = {
                "select": "id,barcode,product_code,parent_tenant_id",
                "vendor_id": f"eq.{resolved_vendor_id}",
                "market_code": f"eq.{market_code}",
                "parent_tenant_id": f"eq.{parent_tenant_id}",
                "limit": str(limit),
                "offset": str(offset),
            }
            batch = client.get_rows("products", params)
            rows_after_sync.extend(batch)
            if len(batch) < limit:
                break
            offset += limit

        image_tasks: list[tuple[int, Path]] = []
        
        # Add tasks for newly inserted products (which were forced to tenant 10)
        for key in newly_inserted_keys:
            source_row = deduped_inserts[key]
            image_key = build_image_key(
                source_row,
                to_text(source_row.get("barcode")),
                to_text(source_row.get("product_code")),
            ).strip().lower()
            local_image_path = local_images.get(image_key)
            if local_image_path is None:
                missing_image_keys += 1
                continue
            
            pids = [
                int(item["id"])
                for item in rows_after_sync
                if (
                    to_text(item.get("barcode")).upper(),
                    to_text(item.get("product_code")).upper(),
                )
                == key
            ]
            if not pids:
                continue
            if len(pids) > 1:
                ambiguous_db_keys += 1
                print(
                    f"Ambiguous product key mapping to multiple database IDs: {key}. "
                    "Skipping image update for this key.",
                    flush=True,
                )
                continue
            
            product_id = pids[0]
            image_tasks.append((product_id, local_image_path))

        # Add tasks for existing excel products that need images
        for product_id, key in existing_excel_needs_image:
            source_row = deduped_inserts[key]
            image_key = build_image_key(
                source_row,
                to_text(source_row.get("barcode")),
                to_text(source_row.get("product_code")),
            ).strip().lower()
            local_image_path = local_images.get(image_key)
            if local_image_path is None:
                missing_image_keys += 1
                continue
            
            image_tasks.append((product_id, local_image_path))

        image_total = len(image_tasks)
        image_start = time.perf_counter()

        if image_total > 0:
            print(f"Uploading images for {image_total} product row(s)...", flush=True)

        def run_image_task(product_id: int, local_path: Path) -> None:
            # helper closure to do upload
            ext = local_path.suffix.lower()
            storage_path = f"{storage_prefix}/{product_id}{ext}"
            content_type = guess_content_type(local_path)
            
            def upload():
                with local_path.open("rb") as f:
                    client.upload_file(storage_bucket, storage_path, f.read(), content_type)
            run_with_retries(upload, retries=3)
            
            public_url = client.get_public_url(storage_bucket, storage_path)
            client.update_row_by_id("products", product_id, {"image_url": public_url})

        if image_total > 0:
            with ThreadPoolExecutor(max_workers=max(1, args.image_workers)) as executor:
                futures = [executor.submit(run_image_task, product_id, local_path) for product_id, local_path in image_tasks]
                done = 0
                for future in as_completed(futures):
                    done += 1
                    try:
                        future.result()
                        image_uploaded += 1
                    except Exception as exc:
                        image_failed += 1
                        print(f"Image phase failed: {exc}", flush=True)
                    if done % 25 == 0 or done == image_total:
                        print_progress("Image uploads", done, image_total, image_start)

    print(
        "Image phase summary: "
        f"uploaded={image_uploaded}, failed={image_failed}, "
        f"missing_source_keys={missing_image_keys}, ambiguous_db_keys={ambiguous_db_keys}",
        flush=True,
    )
    print(
        "Write summary: "
        f"update_failures={update_failures}, insert_failures={insert_failures}",
        flush=True,
    )

    print("Sync complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
