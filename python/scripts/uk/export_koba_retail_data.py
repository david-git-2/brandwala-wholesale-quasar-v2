#!/usr/bin/env python3
"""Scraper for Kobaresell (K-Beauty products) to extract product catalog and upload to public.koba_products (tenant_id = 12)."""

import os
import json
import time
import re
import argparse
import html as htmlmod
from urllib.parse import unquote, urlencode
from typing import Optional, Tuple, List, Dict, Any
from pathlib import Path

from dotenv import load_dotenv
import requests
from bs4 import BeautifulSoup

BASE = "https://www.kobareseller.com"
LOGIN_GET = f"{BASE}/login"
LOGIN_POST = f"{BASE}/login"
CSRF_COOKIE_URL = f"{BASE}/sanctum/csrf-cookie"
PRODUCTS_PATH = "/dashboard/products"

ROOT_DIR = Path(__file__).resolve().parents[3]
load_dotenv(ROOT_DIR / ".env")
load_dotenv(ROOT_DIR / "web" / ".env")
DEFAULT_OUTFILE = ROOT_DIR / "web" / "public" / "uk" / "koba_retail_data.json"

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape Kobaresell products catalog.")
    parser.add_argument(
        "--outfile",
        default=str(DEFAULT_OUTFILE),
        help="Path to output JSON file (default: web/public/uk/koba_retail_data.json)",
    )
    parser.add_argument(
        "--email",
        default=os.getenv("KOBA_EMAIL"),
        help="Kobaresell login email (fallback to KOBA_EMAIL env var)",
    )
    parser.add_argument(
        "--password",
        default=os.getenv("KOBA_PASSWORD"),
        help="Kobaresell login password (fallback to KOBA_PASSWORD env var)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit scraping to N products (0 for unlimited; useful for testing)",
    )
    parser.add_argument(
        "--filter",
        default=os.getenv("KOBA_PRODUCT_FILTER", ""),
        help="Product search query filter (fallback to KOBA_PRODUCT_FILTER env var)",
    )
    parser.add_argument(
        "--per-page",
        type=int,
        default=0,
        help="Products per page (default: use site default)",
    )
    return parser.parse_args()

def extract_brand(name: str) -> str:
    name_lower = name.lower()
    known_brands = [
        "Beauty of Joseon", "The Face Shop", "Green Finger", "On the body", "On The Body", "Dr.Althea", "Dr. Althea",
        "Haruharu Wonder", "Haruharu", "Round Lab", "Dear Klairs", "Klairs", "Pyunkang Yul", "I'm From", "Banila Co",
        "Banila", "A'pieu", "Apieu", "VT Cosmetics", "VT", "Some By Mi", "Axis-Y", "Axis Y", "Heimish", "Skinfood",
        "Nature Republic", "Mediheal", "Innisfree", "Laneige", "Sulwhasoo", "Numbuzin", "Tocobo", "Romand", "rom&nd",
        "TirTir", "TIRTIR", "Abib", "Purito", "Isntree", "Manyo", "Mixsoon", "Anua", "SKIN1004", "Cosrx", "COSRX",
        "Forest", "Phytotree", "Samhyun", "Missha", "Etude", "Kerasys", "Beaute", "Torriden", "Dr.G", "Dr. G", "Manyo Factory"
    ]
    for brand in known_brands:
        if name_lower.startswith(brand.lower()):
            return brand
    # Fallback to the first word
    words = name.split()
    return words[0] if words else ""

def guess_category(name: str) -> str:
    name_lower = name.lower()
    if any(k in name_lower for k in ("sun", "spf", "uv")):
        return "Sun Care"
    if any(k in name_lower for k in ("cleans", "foam", "wash", "water", "cleansing")):
        return "Cleansers"
    if any(k in name_lower for k in ("serum", "ampoule", "essence", "pdrn")):
        return "Serums & Essences"
    if any(k in name_lower for k in ("cream", "moisturizer", "gel", "sleeping", "balm", "lotion")):
        return "Moisturizers"
    if any(k in name_lower for k in ("toner", "toning", "boosting toner")):
        return "Toners"
    if any(k in name_lower for k in ("mask", "sheet", "patch", "pack")):
        return "Masks"
    if any(k in name_lower for k in ("shampoo", "conditioner", "hair", "perfume")):
        return "Hair & Body Care"
    if any(k in name_lower for k in ("lip", "mascara", "shadow", "cushion", "makeup", "brow", "tint")):
        return "Makeup"
    return "Skincare"

def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_-]+', '-', text)
    return text

def get_xsrf_token_from_cookies(session: requests.Session) -> Optional[str]:
    token = session.cookies.get("XSRF-TOKEN")
    return unquote(token) if token else None

def extract_inertia_payload(html_text: str) -> Optional[dict]:
    soup = BeautifulSoup(html_text, "lxml")
    el = soup.select_one("script[data-page]")
    if el and el.name == "script":
        payload = el.string or el.text
        if payload:
            return json.loads(payload)
    el = soup.select_one("#app[data-page]") or soup.select_one("[data-page]")
    if not el:
        return None
    val = el.get("data-page", "")
    if val == "app" and el.name == "script":
        payload = el.string or el.text
        return json.loads(payload)
    return json.loads(htmlmod.unescape(val))

def login_session(email: str, password: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": LOGIN_GET,
        "Origin": BASE,
    })

    s.get(BASE + "/", timeout=30)
    s.get(CSRF_COOKIE_URL, timeout=30)

    xsrf = get_xsrf_token_from_cookies(s)
    if xsrf:
        s.headers["X-XSRF-TOKEN"] = xsrf

    s.get(LOGIN_GET, timeout=30)
    xsrf = get_xsrf_token_from_cookies(s)
    if xsrf:
        s.headers["X-XSRF-TOKEN"] = xsrf

    r = s.post(LOGIN_POST, data={"email": email, "password": password}, timeout=30)
    if r.status_code != 200 or "/login" in r.url:
        raise SystemExit("Login failed (check credentials)")

    return s

def build_products_url(product_filter: str, page: int, per_page: Optional[int]) -> str:
    params = {"page": str(page)}
    if product_filter and product_filter.strip():
        params["product"] = product_filter.strip()
    if per_page:
        params["per_page"] = str(per_page)
    return f"{BASE}{PRODUCTS_PATH}?{urlencode(params)}"

def fetch_page_inertia(s: requests.Session, url: str, retries: int = 3, sleep_seconds: float = 3.0) -> dict:
    last_err = None
    for attempt in range(retries + 1):
        try:
            r = s.get(url, timeout=45)
            if r.status_code == 200 and r.text.strip():
                inertia = extract_inertia_payload(r.text)
                if inertia:
                    return inertia
                last_err = "No Inertia payload found in HTML"
            else:
                last_err = f"HTTP {r.status_code} or empty body"
        except requests.RequestException as e:
            last_err = f"Request error: {e}"

        print(f"⚠️ Warning: Attempt {attempt + 1}/{retries + 1} failed for {url} ({last_err})")
        if attempt < retries:
            time.sleep(sleep_seconds)

    raise SystemExit(f"Failed to fetch/parse page after retries: {last_err}")

def extract_items_and_meta(inertia: dict) -> Tuple[List[Dict[str, Any]], dict]:
    props = inertia.get("props") or {}
    items_obj = props.get("items") or {}
    data = items_obj.get("data")
    meta = items_obj.get("meta") or {}

    if not isinstance(data, list):
        raise SystemExit("Could not find props.items.data list")
    if not isinstance(meta, dict):
        meta = {}

    return data, meta

def get_supabase_creds() -> Tuple[str, str]:
    url = os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL") or ""
    key = os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SERVICE_ROLE_KEY") or ""
    return url.strip(), key.strip()

def upsert_brand(session: requests.Session, base_url: str, headers: dict, tenant_id: int, name: str) -> Optional[int]:
    url = f"{base_url}/rest/v1/koba_brands?on_conflict=tenant_id,name"
    payload = {"tenant_id": tenant_id, "name": name}
    req_headers = dict(headers)
    req_headers["Prefer"] = "return=representation,resolution=merge-duplicates"
    try:
        resp = session.post(url, json=[payload], headers=req_headers, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning upserting brand '{name}': {e}")

    # Fallback: plain GET lookup
    try:
        lookup_url = f"{base_url}/rest/v1/koba_brands"
        params = {"tenant_id": f"eq.{tenant_id}", "name": f"eq.{name}", "select": "id"}
        resp = session.get(lookup_url, headers=headers, params=params, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning fetching brand '{name}': {e}")
    return None


def upsert_category(session: requests.Session, base_url: str, headers: dict, tenant_id: int, name: str) -> Optional[int]:
    url = f"{base_url}/rest/v1/koba_categories?on_conflict=tenant_id,name"
    payload = {"tenant_id": tenant_id, "name": name}
    req_headers = dict(headers)
    req_headers["Prefer"] = "return=representation,resolution=merge-duplicates"
    try:
        resp = session.post(url, json=[payload], headers=req_headers, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning upserting category '{name}': {e}")

    # Fallback: plain GET lookup
    try:
        lookup_url = f"{base_url}/rest/v1/koba_categories"
        params = {"tenant_id": f"eq.{tenant_id}", "name": f"eq.{name}", "select": "id"}
        resp = session.get(lookup_url, headers=headers, params=params, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning fetching category '{name}': {e}")
    return None

def upsert_products_batch(session: requests.Session, base_url: str, headers: dict, batch: List[Dict[str, Any]]):
    url = f"{base_url}/rest/v1/koba_products?on_conflict=tenant_id,source_type,source_id"
    req_headers = dict(headers)
    req_headers["Prefer"] = "resolution=merge-duplicates"
    try:
        resp = session.post(url, json=batch, headers=req_headers, timeout=60)
        if not resp.ok:
            print(f"⚠️ Error upserting product batch: {resp.status_code} - {resp.text}")
    except Exception as e:
        print(f"⚠️ Exception upserting product batch: {e}")

def sync_to_supabase(products: List[Dict[str, Any]], tenant_id: int):
    url, key = get_supabase_creds()
    if not url or not key:
        print("⚠️ Warning: SUPABASE_URL or SUPABASE_SECRET_KEY missing from environment. Skipping database sync.")
        return

    session = requests.Session()
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json"
    }

    print(f"Syncing {len(products)} products to Supabase staging tables for tenant_id {tenant_id} ...")
    
    # 1. Collect unique brands and categories
    unique_brands = set()
    unique_categories = set()
    for p in products:
        b_name = extract_brand(p.get("name", ""))
        if b_name:
            unique_brands.add(b_name)
        c_name = guess_category(p.get("name", ""))
        if c_name:
            unique_categories.add(c_name)

    # 2. Upsert brands & categories to resolve their IDs
    print(f"  Resolving {len(unique_brands)} brand(s)...")
    brand_ids: Dict[str, int] = {}
    for b_name in sorted(unique_brands):
        bid = upsert_brand(session, url, headers, tenant_id, b_name)
        if bid:
            brand_ids[b_name] = bid
            print(f"    ✅ Brand: '{b_name}' → id={bid}")
        else:
            print(f"    ⚠️ Brand: '{b_name}' → could not resolve ID")

    print(f"  Resolving {len(unique_categories)} category/categories...")
    category_ids: Dict[str, int] = {}
    for c_name in sorted(unique_categories):
        cid = upsert_category(session, url, headers, tenant_id, c_name)
        if cid:
            category_ids[c_name] = cid
            print(f"    ✅ Category: '{c_name}' → id={cid}")
        else:
            print(f"    ⚠️ Category: '{c_name}' → could not resolve ID")

    # 3. Map products to db schema
    mapped_products = []
    for p in products:
        name = p.get("name", "")
        b_name = extract_brand(name)
        c_name = guess_category(name)

        sku = p.get("sku") or ""
        prod_id = p.get("id") or ""

        # Store price as provided (assumed GBP)
        price = round(float(p.get("price") or 0), 2)

        commission_pct = p.get("commission_percentage")
        commission = p.get("commission")
        if commission is not None:
            commission = round(float(commission), 2)

        stock_qty = int(p.get("stock_quantity") or 0)
        in_stock = p.get("status") == "in_stock"
        image_url = p.get("image_url") or ""

        db_product = {
            "tenant_id": tenant_id,
            "source_type": "retail",
            "source_id": str(prod_id),
            "name": name,
            "sku": sku,
            "barcode": sku,
            "slug": slugify(name),
            "permalink": "https://www.kobareseller.com/dashboard/products",
            "description": p.get("description", ""),
            "stock_quantity": stock_qty,
            "in_stock": in_stock,
            "price": price,
            "currency": "GBP",
            "commission_percentage": commission_pct,
            "commission": commission,
            "brand_id": brand_ids.get(b_name),
            "category_id": category_ids.get(c_name),
            "image_url": image_url,
            "raw_data": p,
        }
        mapped_products.append(db_product)

    # 4. Batch upsert products
    batch_size = 100
    print(f"  Upserting {len(mapped_products)} product(s) in batches of {batch_size}...")
    for i in range(0, len(mapped_products), batch_size):
        batch = mapped_products[i : i + batch_size]
        upsert_products_batch(session, url, headers, batch)
        print(f"    ✅ Batch {i // batch_size + 1}: upserted {len(batch)} product(s)")

    print(
        f"\n✅ Supabase sync complete — "
        f"{len(mapped_products)} products, "
        f"{len(brand_ids)}/{len(unique_brands)} brands, "
        f"{len(category_ids)}/{len(unique_categories)} categories."
    )

def main():
    args = parse_args()
    
    if not args.email or not args.password:
        raise SystemExit("Missing KOBA_EMAIL or KOBA_PASSWORD credentials. Set them in .env or pass as arguments.")

    outfile = Path(args.outfile).expanduser().resolve()
    
    print(f"Logging in to Kobaresell as {args.email} ...")
    session = login_session(args.email, args.password)
    print("✅ Login successful")

    page = 1
    all_raw_items: List[Dict[str, Any]] = []
    
    # Fetch page 1
    url = build_products_url(args.filter, page, args.per_page if args.per_page > 0 else None)
    print(f"Fetching page {page}: {url}")
    inertia = fetch_page_inertia(session, url)
    items, meta = extract_items_and_meta(inertia)
    
    last_page = 1
    try:
        last_page = int(meta.get("last_page", 1))
    except Exception:
        pass

    print(f"✅ Page 1: retrieved {len(items)} items. Total pages to fetch: {last_page}")
    all_raw_items.extend(items)

    # Fetch subsequent pages
    while page < last_page:
        if args.limit > 0 and len(all_raw_items) >= args.limit:
            break
        page += 1
        url = build_products_url(args.filter, page, args.per_page if args.per_page > 0 else None)
        print(f"Fetching page {page}: {url}")
        inertia = fetch_page_inertia(session, url)
        items, meta = extract_items_and_meta(inertia)
        print(f"✅ Page {page}: retrieved {len(items)} items")
        all_raw_items.extend(items)

    # Deduplicate items
    seen = set()
    deduped_raw = []
    for it in all_raw_items:
        it_id = it.get("id")
        if it_id is None:
            deduped_raw.append(it)
            continue
        if it_id in seen:
            continue
        seen.add(it_id)
        deduped_raw.append(it)

    # Limit products if requested
    if args.limit > 0:
        deduped_raw = deduped_raw[:args.limit]

    # Save unmodified raw JSON data as requested
    outfile.parent.mkdir(parents=True, exist_ok=True)
    with open(outfile, "w", encoding="utf-8") as f:
        json.dump(deduped_raw, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"\n✅ Successfully saved {len(deduped_raw)} raw products to {outfile}")

    # Automatically sync to staging database tables under tenant_id = 12 (Retail)
    try:
        sync_to_supabase(deduped_raw, tenant_id=12)
    except Exception as e:
        print(f"⚠️ Warning: Supabase sync failed: {e}")

if __name__ == "__main__":
    main()
