#!/usr/bin/env python3
"""Sync UK PC JSON products into Supabase products table."""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

try:
    import requests
except ModuleNotFoundError:  # pragma: no cover - handled at runtime
    requests = None  # type: ignore[assignment]

ROOT_DIR = Path(__file__).resolve().parents[3]
WEB_ENV_FILE = ROOT_DIR / "web" / ".env"
ROOT_ENV_FILE = ROOT_DIR / ".env"
DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.json"
DEFAULT_STORAGE_BUCKET = str(os.getenv("PY_SUPABASE_STORAGE_BUCKET") or "product-images").strip()
DEFAULT_STORAGE_PREFIX = str(os.getenv("PY_SUPABASE_STORAGE_PREFIX") or "uk/pc").strip().strip("/")
DEFAULT_IMAGES_DIR = ROOT_DIR / "python" / "images" / "uk" / "out_images"
SNAPSHOT_RETENTION_DAYS = 7
PC_VENDOR_CODE = "PC"
PC_VENDOR_ID = 3


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and (
            (value.startswith('"') and value.endswith('"'))
            or (value.startswith("'") and value.endswith("'"))
        ):
            value = value[1:-1]
        if key:
            os.environ.setdefault(key, value)


load_env_file(WEB_ENV_FILE)
load_env_file(ROOT_ENV_FILE)


def parse_args() -> argparse.Namespace:
    def env_int(name: str, fallback: int) -> int:
        raw = str(os.getenv(name, "")).strip()
        if not raw:
            return fallback
        try:
            parsed = int(raw)
            return parsed if parsed > 0 else fallback
        except ValueError:
            return fallback

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
        "--tenant-id",
        dest="tenant_id",
        default=os.getenv("PY_PRODUCTS_TENANT_ID", "").strip(),
        help="Tenant id scope. Empty value means tenant_id IS NULL.",
    )
    parser.add_argument(
        "--parent-tenant-id",
        dest="parent_tenant_id",
        default=os.getenv("PY_PRODUCTS_PARENT_TENANT_ID", "").strip(),
        help="Parent tenant id for inserts. Empty value means parent_tenant_id IS NULL.",
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


def to_text(value: Any) -> str:
    return str(value if value is not None else "").strip()


def prompt_optional_positive_id(label: str, default_raw: str) -> int | None:
    """Prompt for a positive int when stdin is a TTY; otherwise use default/env/CLI."""
    import sys

    default_text = to_text(default_raw)
    prompt = label
    if default_text:
        prompt += f" [{default_text}]"
    prompt += ": "

    while True:
        if not sys.stdin.isatty():
            if default_text.isdigit() and int(default_text) > 0:
                return int(default_text)
            return None

        raw = input(prompt).strip()
        if raw == "":
            raw = default_text

        if raw == "":
            return None

        if raw.isdigit() and int(raw) > 0:
            return int(raw)

        print(f"Invalid {label.lower()}. Use a positive integer, or leave blank for NULL.", flush=True)


def to_int_or_none(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(round(value))
    text = to_text(value).replace(",", "")
    if text in ("", "-", ".", "-."):
        return None
    try:
        return int(round(float(text)))
    except ValueError:
        return None


def to_float_or_none(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = to_text(value).replace(",", "")
    if text in ("", "-", ".", "-."):
        return None
    try:
        return float(text)
    except ValueError:
        return None


def normalize_nullable_text(value: Any) -> str | None:
    text = to_text(value)
    return text or None


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


def load_products(input_path: Path) -> list[dict[str, Any]]:
    with input_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if isinstance(payload, dict) and isinstance(payload.get("products"), list):
        return payload["products"]
    if isinstance(payload, list):
        return payload
    raise ValueError("Unsupported JSON shape. Expected {'products': [...]} or a list.")


def product_key(row: dict[str, Any]) -> tuple[str, str]:
    return to_text(row.get("barcode")).upper(), to_text(row.get("product_code")).upper()


def build_sync_payloads(
    row: dict[str, Any],
    vendor_code: str,
    vendor_id: int,
    market_code: str,
    tenant_id: int | None,
    parent_tenant_id: int | None,
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
        "tenant_id": tenant_id,
        "parent_tenant_id": parent_tenant_id,
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
        "tariff_code": normalize_nullable_text(row.get("tariff_code")),
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
            "tenant_id",
            "parent_tenant_id",
            "vendor_id",
            "vendor_code",
            "market_code",
            "barcode",
            "product_code",
        ):
            continue
        if value is not None:
            update_payload[key] = value

    return insert_payload, update_payload


class SupabaseRestClient:
    def __init__(self, base_url: str, api_key: str):
        if requests is None:
            raise RuntimeError(
                "Missing Python dependency: requests. "
                "Install with `pip install -r python/requirements.txt` or run `npm run python:pc`."
            )
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "apikey": api_key,
            "Authorization": f"Bearer {api_key}",
        }

    def _url(self, table: str) -> str:
        return f"{self.base_url}/rest/v1/{table}"

    def get_rows(self, table: str, params: dict[str, Any]) -> list[dict[str, Any]]:
        resp = requests.get(self._url(table), headers=self.headers, params=params, timeout=60)
        if not resp.ok:
            raise RuntimeError(f"GET {table} failed ({resp.status_code}): {resp.text}")
        data = resp.json()
        if not isinstance(data, list):
            raise RuntimeError(f"Unexpected {table} response shape: {type(data)}")
        return data

    def insert_rows(self, table: str, rows: list[dict[str, Any]]) -> None:
        if not rows:
            return
        headers = dict(self.headers)
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=minimal"
        resp = requests.post(self._url(table), headers=headers, json=rows, timeout=120)
        if not resp.ok:
            raise RuntimeError(f"INSERT {table} failed ({resp.status_code}): {resp.text}")

    def update_row_by_id(self, table: str, row_id: int, payload: dict[str, Any]) -> None:
        headers = dict(self.headers)
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=minimal"
        params = {"id": f"eq.{row_id}"}
        resp = requests.patch(self._url(table), headers=headers, params=params, json=payload, timeout=120)
        if not resp.ok:
            raise RuntimeError(f"UPDATE {table} id={row_id} failed ({resp.status_code}): {resp.text}")

    def update_rows(self, table: str, params: dict[str, Any], payload: dict[str, Any]) -> None:
        headers = dict(self.headers)
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=minimal"
        resp = requests.patch(self._url(table), headers=headers, params=params, json=payload, timeout=120)
        if not resp.ok:
            raise RuntimeError(f"UPDATE {table} by filter failed ({resp.status_code}): {resp.text}")

    def delete_rows(self, table: str, params: dict[str, Any]) -> None:
        headers = dict(self.headers)
        headers["Prefer"] = "return=minimal"
        resp = requests.delete(self._url(table), headers=headers, params=params, timeout=120)
        if not resp.ok:
            raise RuntimeError(f"DELETE {table} by filter failed ({resp.status_code}): {resp.text}")

    def upload_file(self, bucket: str, object_path: str, data: bytes, content_type: str) -> None:
        url = f"{self.base_url}/storage/v1/object/{bucket}/{object_path}"
        headers = {
            "apikey": self.headers["apikey"],
            "Authorization": self.headers["Authorization"],
            "x-upsert": "true",
            "Content-Type": content_type,
        }
        resp = requests.post(url, headers=headers, data=data, timeout=120)
        if not resp.ok:
            raise RuntimeError(f"supabase storage upload failed ({resp.status_code}): {resp.text}")

    def get_public_url(self, bucket: str, object_path: str) -> str:
        return f"{self.base_url}/storage/v1/object/public/{bucket}/{object_path}"


def fetch_all_scoped_products(
    client: SupabaseRestClient,
    vendor_id: int,
    market_code: str,
    tenant_id: int | None,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    limit = 1000
    while True:
        params: dict[str, Any] = {
            "select": "id,barcode,product_code",
            "vendor_id": f"eq.{vendor_id}",
            "market_code": f"eq.{market_code}",
            "limit": str(limit),
            "offset": str(offset),
        }
        if tenant_id is None:
            params["tenant_id"] = "is.null"
        else:
            params["tenant_id"] = f"eq.{tenant_id}"
        batch = client.get_rows("products", params)
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return rows


def fetch_all_scoped_products_full(
    client: SupabaseRestClient,
    vendor_id: int,
    market_code: str,
    tenant_id: int | None,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    limit = 1000
    while True:
        params: dict[str, Any] = {
            "select": "*",
            "vendor_id": f"eq.{vendor_id}",
            "market_code": f"eq.{market_code}",
            "limit": str(limit),
            "offset": str(offset),
        }
        if tenant_id is None:
            params["tenant_id"] = "is.null"
        else:
            params["tenant_id"] = f"eq.{tenant_id}"
        batch = client.get_rows("products", params)
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return rows


def fetch_vendor_market_rows_any_tenant(
    client: SupabaseRestClient,
    vendor_id: int,
    market_code: str,
    limit: int = 50,
) -> list[dict[str, Any]]:
    return client.get_rows(
        "products",
        {
            "select": "id,tenant_id,barcode,product_code",
            "vendor_id": f"eq.{vendor_id}",
            "market_code": f"eq.{market_code}",
            "limit": str(limit),
        },
    )


def build_scope_params(
    vendor_id: int,
    market_code: str,
    tenant_id: int | None,
) -> dict[str, Any]:
    params: dict[str, Any] = {
        "vendor_id": f"eq.{vendor_id}",
        "market_code": f"eq.{market_code}",
    }
    if tenant_id is None:
        params["tenant_id"] = "is.null"
    else:
        params["tenant_id"] = f"eq.{tenant_id}"
    return params


def ensure_vendor_exists(
    client: SupabaseRestClient,
    vendor_code: str,
    market_code: str,
    tenant_id: int | None,
    dry_run: bool,
) -> dict[str, Any]:
    preferred_code = (
        f"{vendor_code}-{tenant_id}".upper()
        if tenant_id is not None
        else vendor_code.upper()
    )
    candidate_codes = [vendor_code]
    if tenant_id is not None:
        candidate_codes.append(f"{vendor_code}-{tenant_id}")

    code_filter = ",".join(candidate_codes)
    params = {
        "select": "id,code,tenant_id,market_code",
        "code": f"in.({code_filter})",
        "market_code": f"eq.{market_code}",
        "limit": "50",
    }
    if tenant_id is None:
        params["tenant_id"] = "is.null"
    else:
        params["tenant_id"] = f"eq.{tenant_id}"

    rows = client.get_rows("vendors", params)
    if rows:
        rows_sorted = sorted(
            rows,
            key=lambda row: (
                0 if to_text(row.get("code")).upper() == preferred_code else 1,
                int(row.get("id") or 0),
            ),
        )
        return rows_sorted[0]

    payload = {
        "name": vendor_code,
        "code": vendor_code,
        "market_code": market_code,
        "tenant_id": tenant_id,
    }
    if dry_run:
        print(f"[dry-run] would create missing vendor: {payload}")
        # optimistic dry-run preview for later flow
        preview_code = f"{vendor_code}-{tenant_id}" if tenant_id is not None else vendor_code
        return {
            "id": -1,
            "code": preview_code,
            "tenant_id": tenant_id,
            "market_code": market_code,
        }

    client.insert_rows("vendors", [payload])
    print(f"Created missing vendor code={vendor_code} market_code={market_code}")

    rows_after = client.get_rows("vendors", params)
    if not rows_after:
        raise RuntimeError("Vendor was created but could not be resolved by scope.")
    rows_sorted = sorted(
        rows_after,
        key=lambda row: (
            0 if to_text(row.get("code")).upper() == preferred_code else 1,
            int(row.get("id") or 0),
        ),
    )
    return rows_sorted[0]


def get_vendor_by_id(
    client: SupabaseRestClient,
    vendor_id: int,
) -> dict[str, Any]:
    rows = client.get_rows(
        "vendors",
        {
            "select": "id,code,tenant_id,market_code",
            "id": f"eq.{vendor_id}",
            "limit": "1",
        },
    )
    if not rows:
        raise RuntimeError(
            f"Vendor id={vendor_id} not found. "
            "Create/fix this vendor row first, then rerun PC sync."
        )
    return rows[0]


def ensure_market_exists(
    client: SupabaseRestClient,
    market_code: str,
) -> None:
    rows = client.get_rows(
        "markets",
        {
            "select": "code",
            "code": f"eq.{market_code}",
            "limit": "1",
        },
    )
    if not rows:
        raise RuntimeError(
            f"Market code '{market_code}' not found in public.markets. "
            "Create/seed it first, then retry."
        )


def chunked(items: list[dict[str, Any]], size: int) -> list[list[dict[str, Any]]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def normalize_lookup_name(value: Any) -> str | None:
    text = to_text(value)
    return text or None


def fetch_lookup_values_for_vendor(
    client: SupabaseRestClient,
    table: str,
    vendor_id: int,
) -> set[str]:
    rows: list[dict[str, Any]] = []
    offset = 0
    limit = 1000
    while True:
        params = {
            "select": "value",
            "vendor_id": f"eq.{vendor_id}",
            "limit": str(limit),
            "offset": str(offset),
        }
        batch = client.get_rows(table, params)
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit

    return {
        to_text(row.get("value")).lower()
        for row in rows
        if to_text(row.get("value"))
    }


def ensure_lookup_rows_for_new_inserts(
    client: SupabaseRestClient,
    vendor_id: int,
    vendor_code: str,
    inserts: list[dict[str, Any]],
    chunk_size: int,
    dry_run: bool,
    write_retries: int,
) -> None:
    if not inserts:
        return

    existing_brand_values = fetch_lookup_values_for_vendor(client, "product_brands", vendor_id)
    existing_category_values = fetch_lookup_values_for_vendor(client, "product_categories", vendor_id)

    missing_brands: list[dict[str, Any]] = []
    missing_categories: list[dict[str, Any]] = []
    seen_brand_values: set[str] = set()
    seen_category_values: set[str] = set()

    for row in inserts:
        brand_name = normalize_lookup_name(row.get("brand"))
        category_name = normalize_lookup_name(row.get("category"))

        if brand_name:
            brand_value = brand_name.lower()
            if brand_value not in existing_brand_values and brand_value not in seen_brand_values:
                seen_brand_values.add(brand_value)
                missing_brands.append({
                    "name": brand_name,
                    "vendor_id": vendor_id,
                    "vendor_code": vendor_code,
                })

        if category_name:
            category_value = category_name.lower()
            if category_value not in existing_category_values and category_value not in seen_category_values:
                seen_category_values.add(category_value)
                missing_categories.append({
                    "name": category_name,
                    "vendor_id": vendor_id,
                    "vendor_code": vendor_code,
                })

    if dry_run:
        if missing_brands:
            print(f"[dry-run] would insert {len(missing_brands)} missing brand lookup row(s).", flush=True)
        if missing_categories:
            print(f"[dry-run] would insert {len(missing_categories)} missing category lookup row(s).", flush=True)
        return

    for batch in chunked(missing_brands, max(1, chunk_size)):
        run_with_retries(
            lambda b=batch: client.insert_rows("product_brands", b),
            retries=max(1, write_retries),
        )

    for batch in chunked(missing_categories, max(1, chunk_size)):
        run_with_retries(
            lambda b=batch: client.insert_rows("product_categories", b),
            retries=max(1, write_retries),
        )

    if missing_brands or missing_categories:
        print(
            "Lookup sync summary: "
            f"inserted_brands={len(missing_brands)}, inserted_categories={len(missing_categories)}",
            flush=True,
        )


def format_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    if h > 0:
        return f"{h}h {m}m {s}s"
    if m > 0:
        return f"{m}m {s}s"
    return f"{s}s"


def print_progress(label: str, done: int, total: int, start_ts: float) -> None:
    if total <= 0:
        return
    elapsed = max(0.0001, time.perf_counter() - start_ts)
    rate = done / elapsed
    remaining = max(0, total - done)
    eta = remaining / rate if rate > 0 else 0
    percent = (done / total) * 100
    print(
        f"{label}: {done}/{total} ({percent:.1f}%) | {rate:.2f}/s | ETA {format_duration(eta)}",
        flush=True,
    )


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


def run_with_retries(task, retries: int, base_delay_sec: float = 0.35):
    last_error: Exception | None = None
    attempts = max(1, retries)
    for attempt in range(1, attempts + 1):
        try:
            return task()
        except Exception as exc:  # pragma: no cover - retry behavior
            last_error = exc
            if attempt >= attempts:
                break
            time.sleep(min(2.5, base_delay_sec * attempt))
    if last_error is not None:
        raise last_error
    raise RuntimeError("Retry loop ended without result.")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def main() -> int:
    args = parse_args()

    print("Tenant scope (required for product inserts):", flush=True)
    tenant_id = prompt_optional_positive_id("Enter tenant id", to_text(args.tenant_id))
    parent_tenant_id = prompt_optional_positive_id(
        "Enter parent tenant id", to_text(args.parent_tenant_id)
    )
    print(
        f"Using tenant_id={'NULL' if tenant_id is None else tenant_id}, "
        f"parent_tenant_id={'NULL' if parent_tenant_id is None else parent_tenant_id}",
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

    gbp_currency_id_env = to_text(os.getenv("PY_GBP_CURRENCY_ID"))
    if gbp_currency_id_env:
        gbp_currency_id = int(gbp_currency_id_env)
    else:
        gbp_currency_rows = client.get_rows(
            "global_currencies",
            {"code": "eq.GBP", "select": "id", "limit": "1"},
        )
        if not gbp_currency_rows:
            raise RuntimeError(
                "Currency GBP not found in global_currencies. "
                "Apply grant migration or set PY_GBP_CURRENCY_ID."
            )
        gbp_currency_id = int(gbp_currency_rows[0]["id"])

    if args.vendor_id and str(args.vendor_id).strip():
        resolved_vendor_id = int(args.vendor_id)
        vendor_row = get_vendor_by_id(client, resolved_vendor_id)
    elif vendor_code == PC_VENDOR_CODE:
        vendor_row = get_vendor_by_id(client, PC_VENDOR_ID)
        resolved_vendor_id = PC_VENDOR_ID
    else:
        vendor_row = ensure_vendor_exists(client, vendor_code, market_code, tenant_id, args.dry_run)
        resolved_vendor_id = vendor_row["id"]

    resolved_vendor_code = to_text(vendor_row.get("code")).upper() or vendor_code

    vendor_market_code = to_text(vendor_row.get("market_code")).upper()
    if vendor_market_code and vendor_market_code != market_code:
        raise ValueError(
            f"Vendor id {resolved_vendor_id} market mismatch. "
            f"Vendor market={vendor_market_code}, input market={market_code}."
        )

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
            tenant_id,
            parent_tenant_id,
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

    if tenant_id is None:
        sample_rows = fetch_vendor_market_rows_any_tenant(client, resolved_vendor_id, market_code, limit=50)
        tenant_bound = [r for r in sample_rows if r.get("tenant_id") is not None]
        if tenant_bound:
            tenant_sample = ", ".join(
                str(r.get("tenant_id")) for r in tenant_bound[:8]
            )
            raise ValueError(
                "Tenant scope is NULL, but tenant-bound rows already exist for this vendor/market. "
                f"Sample tenant_id values: {tenant_sample}. "
                "Set PY_PRODUCTS_TENANT_ID in web/.env (or pass --tenant-id) and rerun."
            )

    scope_params = build_scope_params(resolved_vendor_id, market_code, tenant_id)
    existing_rows_full = fetch_all_scoped_products_full(client, resolved_vendor_id, market_code, tenant_id)
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

        is_hazardous = insert_payload.get("hazardous") is True
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
                    # If the source is not website (e.g. excel), we update the image.
                    if "image_url" in final_update_payload:
                        del final_update_payload["image_url"]
                    updates.append((row_id, final_update_payload))
                    existing_excel_needs_image.add((row_id, key))
        else:
            insert_payload["tenant_id"] = tenant_id
            insert_payload["parent_tenant_id"] = parent_tenant_id
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
    print(f"Planned availability reset to false: {len(existing_rows)}")
    print(f"Planned updates: {len(updates)}")
    print(f"Planned inserts: {len(inserts)}")
    print(
        "Scope: "
        f"vendor_code={resolved_vendor_code} vendor_id={resolved_vendor_id} "
        f"market={market_code} "
        f"tenant_id={'NULL' if tenant_id is None else tenant_id} "
        f"parent_tenant_id={'NULL' if parent_tenant_id is None else parent_tenant_id}"
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
                "tenant_id": row.get("tenant_id"),
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

    # Availability reset rule:
    # 1) Mark every scoped product unavailable.
    # 2) Products present in current JSON will be set available=true via update/insert.
    print("Applying availability reset (set false for current scope)...", flush=True)
    client.update_rows("products", scope_params, {"is_available": False})
    print("Availability reset complete.", flush=True)

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
                "select": "id,barcode,product_code,tenant_id",
                "vendor_id": f"eq.{resolved_vendor_id}",
                "market_code": f"eq.{market_code}",
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
            
            pids = [int(item["id"]) for item in rows_after_sync if (to_text(item.get("barcode")).upper(), to_text(item.get("product_code")).upper()) == key and item.get("tenant_id") == tenant_id]
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
