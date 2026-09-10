"""Shared helpers for UK product JSON → Supabase sync scripts."""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import requests
except ModuleNotFoundError:  # pragma: no cover - handled at runtime
    requests = None  # type: ignore[assignment]

ROOT_DIR = Path(__file__).resolve().parents[3]
WEB_ENV_FILE = ROOT_DIR / "web" / ".env"
ROOT_ENV_FILE = ROOT_DIR / ".env"
SNAPSHOT_RETENTION_DAYS = 7


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


def env_int(name: str, fallback: int) -> int:
    raw = str(os.getenv(name, "")).strip()
    if not raw:
        return fallback
    try:
        parsed = int(raw)
        return parsed if parsed > 0 else fallback
    except ValueError:
        return fallback


def to_text(value: Any) -> str:
    return str(value if value is not None else "").strip()


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


def fetch_all_scoped_products_full(
    client: SupabaseRestClient,
    vendor_id: int,
    market_code: str,
    parent_tenant_id: int,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    limit = 1000
    while True:
        params: dict[str, Any] = {
            "select": "*",
            "vendor_id": f"eq.{vendor_id}",
            "market_code": f"eq.{market_code}",
            "parent_tenant_id": f"eq.{parent_tenant_id}",
            "limit": str(limit),
            "offset": str(offset),
        }
        batch = client.get_rows("products", params)
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return rows


def build_scope_params(
    vendor_id: int,
    market_code: str,
    parent_tenant_id: int,
) -> dict[str, Any]:
    return {
        "vendor_id": f"eq.{vendor_id}",
        "market_code": f"eq.{market_code}",
        "parent_tenant_id": f"eq.{parent_tenant_id}",
    }


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
            "Create/fix this vendor row first, then rerun sync."
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


def resolve_gbp_currency_id(client: SupabaseRestClient) -> int:
    gbp_currency_id_env = to_text(os.getenv("PY_GBP_CURRENCY_ID"))
    if gbp_currency_id_env:
        return int(gbp_currency_id_env)
    gbp_currency_rows = client.get_rows(
        "global_currencies",
        {"code": "eq.GBP", "select": "id", "limit": "1"},
    )
    if not gbp_currency_rows:
        raise RuntimeError(
            "Currency GBP not found in global_currencies. "
            "Apply grant migration or set PY_GBP_CURRENCY_ID."
        )
    return int(gbp_currency_rows[0]["id"])


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
