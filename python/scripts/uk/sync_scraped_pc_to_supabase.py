#!/usr/bin/env python3
"""Sync scraped PriceCheck JSON products into Supabase products table."""

from __future__ import annotations
import os
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import requests
except ModuleNotFoundError:
    print("Error: 'requests' module not found. Please install it using pip.")
    exit(1)

# Paths
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parents[2]
WEB_ENV_FILE = ROOT_DIR / "web" / ".env"
ROOT_ENV_FILE = ROOT_DIR / ".env"
INPUT_JSON = ROOT_DIR / "web" / "public" / "uk" / "pc_scraped_data.json"

PC_VENDOR_ID = 3
PC_VENDOR_CODE = "PC"
MARKET_CODE = "GB"
TENANT_ID = 10

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

class SupabaseRestClient:
    def __init__(self, base_url: str, api_key: str):
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

def to_text(value: Any) -> str:
    return str(value if value is not None else "").strip()

def to_float_or_none(value: Any) -> float | None:
    if value is None:
        return None
    text = to_text(value).replace(",", "")
    try:
        return float(text)
    except ValueError:
        return None

def fetch_lookup_values(client: SupabaseRestClient, table: str, vendor_id: int, vendor_code: str) -> set[str]:
    rows: list[dict[str, Any]] = []
    offset = 0
    limit = 1000
    while True:
        params = {
            "select": "value",
            "or": f"(vendor_id.eq.{vendor_id},vendor_code.eq.{vendor_code})",
            "limit": str(limit),
            "offset": str(offset),
        }
        batch = client.get_rows(table, params)
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return {to_text(row.get("value")).lower() for row in rows if to_text(row.get("value"))}

def ensure_lookups(client: SupabaseRestClient, products: list[dict[str, Any]]) -> None:
    existing_brands = fetch_lookup_values(client, "product_brands", PC_VENDOR_ID, PC_VENDOR_CODE)
    existing_categories = fetch_lookup_values(client, "product_categories", PC_VENDOR_ID, PC_VENDOR_CODE)

    missing_brands = []
    missing_categories = []
    seen_brands = set()
    seen_categories = set()

    for p in products:
        b_name = to_text(p.get("brand"))
        c_name = to_text(p.get("category"))

        if b_name:
            b_val = b_name.lower()
            if b_val not in existing_brands and b_val not in seen_brands:
                seen_brands.add(b_val)
                missing_brands.append({
                    "name": b_name,
                    "vendor_id": PC_VENDOR_ID,
                    "vendor_code": PC_VENDOR_CODE,
                    "tenant_id": TENANT_ID,
                })

        if c_name:
            c_val = c_name.lower()
            if c_val not in existing_categories and c_val not in seen_categories:
                seen_categories.add(c_val)
                missing_categories.append({
                    "name": c_name,
                    "vendor_id": PC_VENDOR_ID,
                    "vendor_code": PC_VENDOR_CODE,
                    "tenant_id": TENANT_ID,
                })

    if missing_brands:
        print(f"Adding {len(missing_brands)} missing brand lookup rows...")
        client.insert_rows("product_brands", missing_brands)
    if missing_categories:
        print(f"Adding {len(missing_categories)} missing category lookup rows...")
        client.insert_rows("product_categories", missing_categories)

def chunked(items: list[Any], size: int) -> list[list[Any]]:
    return [items[i : i + size] for i in range(0, len(items), size)]

def run_with_retries(task, retries: int = 3, delay: float = 0.5):
    for attempt in range(1, retries + 1):
        try:
            return task()
        except Exception as exc:
            if attempt >= retries:
                raise exc
            time.sleep(delay * attempt)

def main():
    supabase_url = to_text(os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL"))
    supabase_key = to_text(os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY"))

    if not supabase_url or not supabase_key:
        print("❌ Error: Missing SUPABASE_URL or SUPABASE_SECRET_KEY in environment variables.")
        exit(1)

    print(f"📥 Loading scraped products from {INPUT_JSON}...")
    if not INPUT_JSON.exists():
        print(f"❌ Error: Scraped products file not found at {INPUT_JSON}")
        exit(1)

    with INPUT_JSON.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    
    scraped_products = payload.get("products", [])
    if not scraped_products:
        print("⚠️ Warning: No products found in the scraped JSON file.")
        return

    print(f"📦 Found {len(scraped_products)} scraped products.")

    client = SupabaseRestClient(supabase_url, supabase_key)

    # 1. Ensure Brands & Categories lookup rows exist
    print("🔍 Syncing lookup tables (brands & categories)...")
    ensure_lookups(client, scraped_products)

    # 2. Fetch existing products for this vendor+market+tenant
    print("🔍 Fetching existing products in database...")
    existing_rows = []
    offset = 0
    limit = 1000
    while True:
        params = {
            "select": "id,barcode,product_code",
            "vendor_id": f"eq.{PC_VENDOR_ID}",
            "market_code": f"eq.{MARKET_CODE}",
            "tenant_id": f"eq.{TENANT_ID}",
            "limit": str(limit),
            "offset": str(offset),
        }
        batch = client.get_rows("products", params)
        existing_rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit

    print(f"Found {len(existing_rows)} existing products in database for this scope.")

    # Index existing products by (barcode, product_code)
    existing_by_key: dict[tuple[str, str], list[int]] = {}
    for item in existing_rows:
        key = (to_text(item.get("barcode")).upper(), to_text(item.get("product_code")).upper())
        if not key[0] or not key[1]:
            continue
        existing_by_key.setdefault(key, []).append(int(item["id"]))

    # 3. Apply availability reset: mark all existing products as unavailable first
    print("Applying availability reset (setting is_available=False for all existing scoped products)...")
    client.update_rows("products", {
        "vendor_id": f"eq.{PC_VENDOR_ID}",
        "market_code": f"eq.{MARKET_CODE}",
        "tenant_id": f"eq.{TENANT_ID}",
    }, {"is_available": False})

    # 4. Prepare updates and inserts
    updates: list[tuple[int, dict[str, Any]]] = []
    inserts: list[dict[str, Any]] = []

    for row in scraped_products:
        barcode = to_text(row.get("barcode"))
        sku = to_text(row.get("product_code"))
        if not barcode or not sku:
            continue

        key = (barcode.upper(), sku.upper())

        # Construct payload matching db columns
        payload = {
            "name": to_text(row.get("name") or row.get("title")),
            "price_gbp": to_float_or_none(row.get("price")),
            "brand": to_text(row.get("brand")) or None,
            "category": to_text(row.get("category")) or None,
            "available_units": int(row.get("available_units") or 0),
            "minimum_order_quantity": int(row.get("case_size") or 1),
            "image_url": to_text(row.get("imageUrl") or row.get("image")) or None,
            "is_available": True
        }

        ids = existing_by_key.get(key, [])
        if ids:
            # Existing product: update it
            for row_id in ids:
                updates.append((row_id, payload))
        else:
            # New product: insert it
            insert_payload = dict(payload)
            insert_payload.update({
                "tenant_id": TENANT_ID,
                "vendor_id": PC_VENDOR_ID,
                "vendor_code": PC_VENDOR_CODE,
                "market_code": MARKET_CODE,
                "barcode": barcode,
                "product_code": sku
            })
            inserts.append(insert_payload)

    print(f"Planned updates: {len(updates)}")
    print(f"Planned inserts: {len(inserts)}")

    # 5. Apply Updates in parallel
    if updates:
        print(f"Applying {len(updates)} product updates...")
        updates_start = time.perf_counter()
        
        def run_update(row_id: int, pld: dict[str, Any]) -> None:
            run_with_retries(lambda: client.update_row_by_id("products", row_id, pld))

        with ThreadPoolExecutor(max_workers=16) as executor:
            futures = [executor.submit(run_update, r_id, pld) for r_id, pld in updates]
            done = 0
            failures = 0
            for fut in as_completed(futures):
                done += 1
                try:
                    fut.result()
                except Exception as exc:
                    failures += 1
                    print(f"Update failed: {exc}")
                if done % 100 == 0 or done == len(updates):
                    elapsed = time.perf_counter() - updates_start
                    rate = done / elapsed if elapsed > 0 else 0
                    print(f"Updates: {done}/{len(updates)} ({done/len(updates)*100:.1f}%) | Rate: {rate:.1f}/s")
            if failures > 0:
                print(f"⚠️ Warning: {failures} updates failed.")

    # 6. Apply Inserts in batches
    if inserts:
        print(f"Applying {len(inserts)} product inserts...")
        insert_batches = chunked(inserts, 250)
        inserts_start = time.perf_counter()
        
        def run_insert(batch: list[dict[str, Any]]) -> None:
            run_with_retries(lambda: client.insert_rows("products", batch))

        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = [executor.submit(run_insert, b) for b in insert_batches]
            done = 0
            failures = 0
            for fut in as_completed(futures):
                done += 1
                try:
                    fut.result()
                except Exception as exc:
                    failures += 1
                    print(f"Insert batch failed: {exc}")
                if done % 5 == 0 or done == len(insert_batches):
                    elapsed = time.perf_counter() - inserts_start
                    rate = (done * 250) / elapsed if elapsed > 0 else 0
                    print(f"Insert batches: {done}/{len(insert_batches)} ({done/len(insert_batches)*100:.1f}%) | Rate: {rate:.1f}/s")
            if failures > 0:
                print(f"⚠️ Warning: {failures} insert batches failed.")

    print("\n✅ Database sync complete successfully!")

if __name__ == "__main__":
    main()
