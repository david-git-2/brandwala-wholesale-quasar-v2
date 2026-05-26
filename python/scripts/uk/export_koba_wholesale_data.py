#!/usr/bin/env python3
"""Scraper for Koba International (kobainternational.com) WooCommerce catalog and upload to public.koba_products (tenant_id = 13)."""

import os
import json
import time
import re
import argparse
import html as htmlmod
from pathlib import Path
from typing import Optional, Tuple, List, Dict, Any

from dotenv import load_dotenv
import requests
from bs4 import BeautifulSoup

BASE_URL = "https://www.kobainternational.com/wp-json/wc/store/v1/products"
ROOT_DIR = Path(__file__).resolve().parents[3]
load_dotenv(ROOT_DIR / ".env")
load_dotenv(ROOT_DIR / "web" / ".env")
DEFAULT_OUTFILE = ROOT_DIR / "web" / "public" / "uk" / "koba_wholesale_data.json"

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape Koba International WooCommerce products.")
    parser.add_argument(
        "--outfile",
        default=str(DEFAULT_OUTFILE),
        help="Path to output JSON file (default: web/public/uk/koba_wholesale_data.json)",
    )
    parser.add_argument(
        "--email",
        default=os.getenv("KOBA_EMAIL"),
        help="Login email (fallback to KOBA_EMAIL env var)",
    )
    parser.add_argument(
        "--password",
        default=os.getenv("KOBA_PASSWORD"),
        help="Login password (fallback to KOBA_PASSWORD env var)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit scraping to N products (0 for unlimited; useful for testing)",
    )
    return parser.parse_args()

def login_session(session: requests.Session, email: str, password: str):
    login_url = "https://www.kobainternational.com/my-account/"
    print(f"Retrieving login page to extract nonce...")
    try:
        r = session.get(login_url, timeout=30)
        if r.status_code != 200:
            print(f"Warning: Failed to load login page ({r.status_code}). Trying direct post...")
            nonce = ""
        else:
            soup = BeautifulSoup(r.text, "lxml")
            nonce_el = soup.find("input", {"name": "woocommerce-login-nonce"})
            nonce = nonce_el["value"] if nonce_el else ""
    except Exception as e:
        print(f"Warning: Connection error loading login page ({e}). Trying direct post...")
        nonce = ""

    payload = {
        "username": email,
        "password": password,
        "woocommerce-login-nonce": nonce,
        "login": "Log in"
    }

    print("Logging in to Koba International...")
    try:
        r_post = session.post(login_url, data=payload, timeout=30)
        if r_post.status_code == 200 and "my-account" in r_post.url:
            print("✅ Login successful (session cookies stored)")
        else:
            print("⚠️ Warning: Login might have failed or redirects occurred. Proceeding anyway...")
    except Exception as e:
        print(f"⚠️ Warning: Connection error posting credentials ({e}). Proceeding as guest...")

def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_-]+', '-', text)
    return text

def get_supabase_creds() -> Tuple[str, str]:
    url = os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL") or ""
    key = os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SERVICE_ROLE_KEY") or ""
    return url.strip(), key.strip()

def upsert_brand(session: requests.Session, base_url: str, headers: dict, tenant_id: int, name: str) -> Optional[int]:
    url = f"{base_url}/rest/v1/koba_brands"
    payload = {"tenant_id": tenant_id, "name": name}
    req_headers = dict(headers)
    req_headers["Prefer"] = "return=representation,resolution=merge-duplicates"
    try:
        resp = session.post(url, json=payload, headers=req_headers, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning upserting brand '{name}': {e}")
        
    # Fallback lookup
    try:
        params = {"tenant_id": f"eq.{tenant_id}", "name": f"eq.{name}"}
        resp = session.get(url, headers=headers, params=params, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning fetching brand '{name}': {e}")
    return None

def upsert_category(session: requests.Session, base_url: str, headers: dict, tenant_id: int, name: str) -> Optional[int]:
    url = f"{base_url}/rest/v1/koba_categories"
    payload = {"tenant_id": tenant_id, "name": name}
    req_headers = dict(headers)
    req_headers["Prefer"] = "return=representation,resolution=merge-duplicates"
    try:
        resp = session.post(url, json=payload, headers=req_headers, timeout=30)
        if resp.ok:
            data = resp.json()
            if data and isinstance(data, list):
                return data[0].get("id")
    except Exception as e:
        print(f"Warning upserting category '{name}': {e}")
        
    # Fallback lookup
    try:
        params = {"tenant_id": f"eq.{tenant_id}", "name": f"eq.{name}"}
        resp = session.get(url, headers=headers, params=params, timeout=30)
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
    
    # 1. Collect unique brands and categories from WooCommerce structure
    unique_brands = set()
    unique_categories = set()
    for p in products:
        brands = p.get("brands")
        if isinstance(brands, list) and len(brands) > 0:
            b_name = brands[0].get("name")
            if b_name:
                unique_brands.add(b_name)
                
        categories = p.get("categories")
        if isinstance(categories, list) and len(categories) > 0:
            c_name = categories[0].get("name")
            if c_name:
                # Decode HTML entities if any (e.g. &amp;)
                c_name = htmlmod.unescape(c_name)
                unique_categories.add(c_name)

    # 2. Upsert brands & categories to resolve their IDs
    print(f"Resolving {len(unique_brands)} brands...")
    brand_ids = {}
    for b_name in unique_brands:
        bid = upsert_brand(session, url, headers, tenant_id, b_name)
        if bid:
            brand_ids[b_name] = bid

    print(f"Resolving {len(unique_categories)} categories...")
    category_ids = {}
    for c_name in unique_categories:
        cid = upsert_category(session, url, headers, tenant_id, c_name)
        if cid:
            category_ids[c_name] = cid

    # 3. Map products to db schema
    mapped_products = []
    for p in products:
        name = p.get("name", "")
        slug = p.get("slug") or slugify(name)
        permalink = p.get("permalink") or ""
        prod_id = p.get("id") or ""
        sku = p.get("sku") or ""
        
        # WooCommerce stores prices inside a nested object
        prices_obj = p.get("prices") or {}
        price_str = prices_obj.get("price") or "0"
        reg_price_str = prices_obj.get("regular_price") or "0"
        sale_price_str = prices_obj.get("sale_price") or "0"
        currency = prices_obj.get("currency_code") or "GBP"
        
        # Convert prices (they are strings e.g. "730", BDT currency has minor unit 0 as per JSON)
        # BDT price is BDT 730, so BDT price does not need to be divided by 100
        # Check minor unit: BDT currency has minor unit 0 in Koba International API
        price = round(float(price_str), 2)
        regular_price = round(float(reg_price_str), 2)
        sale_price = round(float(sale_price_str), 2)
        
        in_stock = p.get("is_in_stock", True)
        # WooCommerce api does not give stock count directly in basic list, check stock_availability or low_stock
        stock_qty = 0
        if in_stock:
            stock_qty = 100  # fallback arbitrary positive stock for in_stock products
            
        images = p.get("images")
        image_url = ""
        if isinstance(images, list) and len(images) > 0:
            image_url = images[0].get("src") or ""
            
        # Extract associated brand and category names
        b_name = ""
        brands = p.get("brands")
        if isinstance(brands, list) and len(brands) > 0:
            b_name = brands[0].get("name") or ""
            
        c_name = ""
        categories = p.get("categories")
        if isinstance(categories, list) and len(categories) > 0:
            c_name = htmlmod.unescape(categories[0].get("name") or "")

        db_product = {
            "tenant_id": tenant_id,
            "source_type": "wholesale",
            "source_id": str(prod_id),
            "name": name,
            "sku": sku,
            "barcode": sku,
            "slug": slug,
            "permalink": permalink,
            "description": p.get("description", ""),
            "stock_quantity": stock_qty,
            "in_stock": in_stock,
            "price": price,
            "regular_price": regular_price,
            "sale_price": sale_price,
            "currency": currency,
            "brand_id": brand_ids.get(b_name),
            "category_id": category_ids.get(c_name),
            "image_url": image_url,
            "raw_data": p
        }
        mapped_products.append(db_product)

    # 4. Batch upsert products
    batch_size = 100
    print(f"Upserting products in batches of {batch_size}...")
    for i in range(0, len(mapped_products), batch_size):
        batch = mapped_products[i:i + batch_size]
        upsert_products_batch(session, url, headers, batch)

    print("✅ Supabase staging sync complete.")

def main():
    args = parse_args()
    outfile = Path(args.outfile).expanduser().resolve()

    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"
    })

    if args.email and args.password:
        login_session(session, args.email, args.password)
    else:
        print("No credentials supplied. Proceeding as guest...")

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

    all_products: List[Dict[str, Any]] = []
    all_products.extend(r.json())

    # Limit check
    if args.limit > 0 and len(all_products) >= args.limit:
        all_products = all_products[:args.limit]
        total_pages = 1

    # Fetch remaining pages
    page = 1
    while page < total_pages:
        if args.limit > 0 and len(all_products) >= args.limit:
            break
        page += 1
        print(f"Fetching page {page} of {total_pages}...")
        params["page"] = page
        try:
            r = session.get(BASE_URL, params=params, timeout=30)
            if r.status_code == 200:
                all_products.extend(r.json())
            else:
                print(f"⚠️ Warning: Error fetching page {page}: {r.status_code}")
        except Exception as e:
            print(f"⚠️ Warning: Connection error on page {page} ({e})")
        time.sleep(1)

    if args.limit > 0:
        all_products = all_products[:args.limit]

    # Save unmodified raw JSON data as requested
    outfile.parent.mkdir(parents=True, exist_ok=True)
    with open(outfile, "w", encoding="utf-8") as f:
        json.dump(all_products, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"\n✅ Successfully saved {len(all_products)} raw products to {outfile}")

    # Automatically sync to staging database tables under tenant_id = 13 (Wholesale)
    try:
        sync_to_supabase(all_products, tenant_id=13)
    except Exception as e:
        print(f"⚠️ Warning: Supabase sync failed: {e}")

if __name__ == "__main__":
    main()
