#!/usr/bin/env python3
"""Scrapes wholesaletradingsupplies.com product catalog and saves data to JSON."""

import os
import re
import json
import time
import html
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

# Paths relative to this script
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parents[2]
WEB_ENV_FILE = ROOT_DIR / "web" / ".env"
ROOT_ENV_FILE = ROOT_DIR / ".env"

DEFAULT_OUT_JSON = ROOT_DIR / "web" / "public" / "uk" / "wts_data.json"
DEFAULT_OUT_MANIFEST = ROOT_DIR / "web" / "public" / "uk" / "wts_manifest.json"
DEFAULT_OUT_IMAGES_DIR = ROOT_DIR / "python" / "images" / "uk" / "wts_images"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

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

# Load env variables
load_env_file(WEB_ENV_FILE)
load_env_file(ROOT_ENV_FILE)

def make_request(url: str, binary: bool = False, retries: int = 3, timeout: int = 15) -> bytes | str | None:
    import random
    # Add a polite random jitter delay to prevent rate limits
    time.sleep(random.uniform(0.25, 1.25))
    req = urllib.request.Request(url, headers=HEADERS)
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                if binary:
                    return response.read()
                return response.read().decode("utf-8", errors="ignore")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                print(f"❌ 404 Not Found: {url}")
                return None
            if e.code in (403, 429):
                print(f"⚠️ HTTPError {e.code} on {url} (Attempt {attempt}/{retries}). Rate limited/blocked, backing off...")
                # Back off significantly to let the block clear
                time.sleep(8.0 * attempt)
                continue
            print(f"⚠️ HTTPError {e.code} on {url} (Attempt {attempt}/{retries})")
        except Exception as e:
            print(f"⚠️ Error on {url}: {e} (Attempt {attempt}/{retries})")
        if attempt < retries:
            time.sleep(2.0 * attempt)
    return None
def clean_category_name(slug: str) -> str:
    overrides = {
        "cotton-wool-and-buds": "Cotton Wool & Buds",
        "roll-ons-and-sticks": "Roll-ons & Sticks",
    }
    if slug in overrides:
        return overrides[slug]
    return slug.replace("-", " ").title()

def get_category_urls() -> list[str]:
    sitemap_url = "https://wholesaletradingsupplies.com/product_category-sitemap.xml"
    print(f"Fetching category sitemap: {sitemap_url}...")
    xml_data = make_request(sitemap_url, binary=True)
    urls = []
    if not xml_data:
        return urls
    try:
        root = ET.fromstring(xml_data)
        namespace = {'ns': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
        for url_tag in root.findall('ns:url', namespace):
            loc = url_tag.find('ns:loc', namespace)
            if loc is not None and loc.text:
                url = loc.text.strip()
                if "/product-category/" in url:
                    urls.append(url)
    except Exception as e:
        print(f"❌ Failed to parse XML for category sitemap: {e}")
    return sorted(list(set(urls)))

def scrape_category_pages(category_url: str) -> list[tuple[str, str]]:
    match = re.search(r"/product-category/([^/]+)/", category_url)
    if not match:
        return []
    slug = match.group(1)
    category_name = clean_category_name(slug)
    
    product_mappings = []
    current_url = category_url
    page_num = 1
    
    while current_url:
        html_content = make_request(current_url)
        if not html_content:
            break
            
        urls = re.findall(r"https://wholesaletradingsupplies.com/product/[^/\"'\s]+/?", html_content)
        for url in urls:
            normalized_url = url.rstrip("/") + "/"
            product_mappings.append((normalized_url, category_name))
            
        next_match = re.search(r"<link\s+rel=['\"]next['\"]\s+href=['\"]([^'\"]+)['\"]", html_content)
        if next_match:
            current_url = next_match.group(1)
            page_num += 1
        else:
            current_url = None
            
    return product_mappings

def build_category_map(workers: int = 10) -> dict[str, str]:
    category_urls = get_category_urls()
    print(f"Found {len(category_urls)} categories to crawl for product-to-category mapping.")
    
    category_map = {}
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(scrape_category_pages, url): url for url in category_urls}
        for future in as_completed(futures):
            url = futures[future]
            try:
                mappings = future.result()
                for prod_url, cat_name in mappings:
                    category_map[prod_url] = cat_name
            except Exception as e:
                print(f"❌ Failed to crawl category pages for {url}: {e}")
                
    print(f"Built category map with {len(category_map)} product URLs.")
    return category_map

def get_product_urls() -> list[str]:
    sitemaps = [
        "https://wholesaletradingsupplies.com/product-sitemap.xml",
        "https://wholesaletradingsupplies.com/product-sitemap2.xml"
    ]
    urls = []
    for sitemap_url in sitemaps:
        print(f"Fetching sitemap: {sitemap_url}...")
        xml_data = make_request(sitemap_url, binary=True)
        if not xml_data:
            continue
        try:
            root = ET.fromstring(xml_data)
            namespace = {'ns': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
            for url_tag in root.findall('ns:url', namespace):
                loc = url_tag.find('ns:loc', namespace)
                if loc is not None and loc.text:
                    url = loc.text.strip()
                    # Exclude the shop archive page
                    if url != "https://wholesaletradingsupplies.com/shop/" and "/product/" in url:
                        urls.append(url)
        except Exception as e:
            print(f"❌ Failed to parse XML for sitemap {sitemap_url}: {e}")
    return sorted(list(set(urls)))

def unescape_text(text: str) -> str:
    if not text:
        return ""
    curr = str(text)
    for _ in range(3):
        prev = curr
        curr = html.unescape(curr)
        if curr == prev:
            break
    return curr.strip()

def parse_product_html(html_content: str, url: str) -> dict | None:
    data = {}
    
    # 1. Try to find the data-item JSON representation (Yoast/sage metadata)
    json_match = re.search(r"data-item='({[^']+})'", html_content)
    if json_match:
        try:
            item_json = json.loads(json_match.group(1))
            data.update({
                "title": item_json.get("title"),
                "price": float(item_json.get("price", 0)),
                "original_image_url": item_json.get("image"),
                "packsize": item_json.get("packsize"),
                "permalink": item_json.get("permalink", url),
                "id": str(item_json.get("id"))
            })
        except Exception as e:
            print(f"⚠️ Error parsing data-item JSON for {url}: {e}")

    # Fallbacks/additional extracts
    if not data.get("title"):
        title_match = re.search(r"<title>([^<]+)</title>", html_content)
        if title_match:
            data["title"] = title_match.group(1).replace("- Wholesale Trading Supplies", "").strip()

    # Extract Brand
    brand_match = re.search(r"Brand:</strong>\s*([^<]+)", html_content)
    if brand_match:
        data["brand"] = brand_match.group(1).strip()
    else:
        data["brand"] = ""

    # Extract Barcode Inner / EAN
    barcode_match = re.search(r"Barcode:&nbsp;</strong>\s*([0-9a-zA-Z\s\-]+)</div>", html_content)
    if barcode_match:
        data["barcode"] = barcode_match.group(1).strip()
    else:
        # Alt check
        barcode_match_alt = re.search(r"Barcode:.*?</strong>\s*([^<]+)", html_content, re.IGNORECASE)
        if barcode_match_alt:
            data["barcode"] = barcode_match_alt.group(1).strip().replace("&nbsp;", "")
        else:
            data["barcode"] = ""

    # Extract Barcode Outer / Carton EAN
    barcode_outer_match = re.search(r"Barcode Outer:&nbsp;</strong>\s*([0-9a-zA-Z\s\-]+)</div>", html_content)
    if barcode_outer_match:
        data["barcode_outer"] = barcode_outer_match.group(1).strip()
    else:
        data["barcode_outer"] = ""

    # Extract Description
    desc_match = re.search(r"Description:&nbsp;</strong>\s*(<p>.*?</p>)\s*</div>", html_content, re.DOTALL)
    if desc_match:
        data["description"] = re.sub(r"<[^>]+>", "", desc_match.group(1)).strip()
    else:
        data["description"] = ""

    # Ensure required components are present
    if not data.get("id"):
        # Try to find post ID in body classes e.g. postid-4055
        postid_match = re.search(r"postid-(\d+)", html_content)
        if postid_match:
            data["id"] = postid_match.group(1)
        else:
            return None

    # Handle Barcode / Product Code / Product ID mapping to match existing schema
    post_id = data["id"]
    barcode = data.get("barcode", "").strip()
    if not barcode:
        barcode = f"WTS_NO_BARCODE_{post_id}"
        data["barcode"] = barcode

    product_code = f"WTS_{post_id}"
    product_id = f"{barcode}_{product_code}"
    image_key = f"{barcode}__{product_code}"

    # Build canonical schema structure compatible with Supabase sync
    data.update({
        "product_code": product_code,
        "product_id": product_id,
        "imageKey": image_key,
        "imageUrl": None,
        "imageUploaded": False,
        "expire_date": ""
    })

    # Clean HTML entities from parsed text fields
    if "title" in data and data["title"]:
        data["title"] = unescape_text(data["title"])
    if "brand" in data and data["brand"]:
        data["brand"] = unescape_text(data["brand"])
    if "description" in data and data["description"]:
        data["description"] = unescape_text(data["description"])

    # Standardizing numeric values
    try:
        data["case_size"] = int(data.get("packsize", 1))
    except (ValueError, TypeError):
        data["case_size"] = 1

    data["minimum_quantity"] = data["case_size"]

    return data

def download_product_image(image_url: str, image_key: str, out_dir: Path) -> str | None:
    if not image_url:
        return None
    
    # Get extension
    ext_match = re.search(r"\.([a-zA-Z0-9]+)(?:\?|$)", image_url)
    ext = ext_match.group(1).lower() if ext_match else "jpg"
    if ext == "jpeg":
        ext = "jpg"
        
    filename = f"{image_key}.{ext}"
    dest_path = out_dir / filename
    
    # Skip if already exists
    if dest_path.exists() and dest_path.stat().st_size > 0:
        return str(dest_path)
        
    img_data = make_request(image_url, binary=True)
    if img_data:
        try:
            dest_path.write_bytes(img_data)
            return str(dest_path)
        except Exception as e:
            print(f"❌ Failed to save image {filename}: {e}")
    return None

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

def scrape_worker(url: str, out_images_dir: Path, category_map: dict, skip_images: bool = False) -> dict | None:
    html = make_request(url)
    if not html:
        return None
    product_data = parse_product_html(html, url)
    if product_data:
        # Set category
        normalized_url = url.rstrip("/") + "/"
        product_data["category"] = category_map.get(normalized_url, "")

        # Download image
        if not skip_images:
            img_url = product_data.get("original_image_url")
            image_key = product_data.get("imageKey")
            if img_url and image_key:
                download_product_image(img_url, image_key, out_images_dir)
    return product_data

def main():
    t0 = time.perf_counter()
    
    import argparse
    parser = argparse.ArgumentParser(description="Scrapes Wholesale Trading Supplies.")
    parser.add_argument("--output", default=str(DEFAULT_OUT_JSON), help="Output JSON path")
    parser.add_argument("--images-dir", default=str(DEFAULT_OUT_IMAGES_DIR), help="Output images directory")
    parser.add_argument("--workers", type=int, default=3, help="Number of concurrent worker threads")
    parser.add_argument("--limit", type=int, default=0, help="Limit the number of products to scrape (0 for unlimited)")
    parser.add_argument("--skip-images", action="store_true", help="Skip downloading product images locally during scraping.")
    args = parser.parse_args()

    out_json = Path(args.output).expanduser().resolve()
    out_images = Path(args.images_dir).expanduser().resolve()
    
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_images.mkdir(parents=True, exist_ok=True)

    print("\n==============================================")
    print("🚀 WHOLESALE TRADING SUPPLIES SCRAPER STARTING")
    print(f"📁 Output JSON: {out_json}")
    print(f"📁 Output Images: {out_images}")
    print(f"🧵 Concurrency: {args.workers} workers")
    if args.limit > 0:
        print(f"🛑 Limit: {args.limit} items")
    print("==============================================\n")

    # 0. Build category map
    category_map = build_category_map(args.workers)

    # 1. Fetch all product URLs
    product_urls = get_product_urls()
    if args.limit > 0:
        product_urls = product_urls[:args.limit]
    total_products = len(product_urls)
    print(f"Found {total_products} products to scrape.\n")
    
    if total_products == 0:
        print("❌ No products found. Exiting.")
        return 1

    # 2. Scrape concurrently
    products = []
    scraped_count = 0
    start_ts = time.perf_counter()

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(scrape_worker, url, out_images, category_map, args.skip_images): url for url in product_urls}
        
        for future in as_completed(futures):
            url = futures[future]
            scraped_count += 1
            try:
                data = future.result()
                if data:
                    products.append(data)
            except Exception as e:
                print(f"❌ Worker crashed for URL {url}: {e}")
                
            # Log progress every 20 products
            if scraped_count % 20 == 0 or scraped_count == total_products:
                elapsed = max(0.0001, time.perf_counter() - start_ts)
                rate = scraped_count / elapsed
                remaining = total_products - scraped_count
                eta = remaining / rate if rate > 0 else 0
                percent = (scraped_count / total_products) * 100
                print(
                    f"Progress: {scraped_count}/{total_products} ({percent:.1f}%) | "
                    f"{rate:.2f}/s | ETA {format_duration(eta)}",
                    flush=True
                )

    # 3. Save JSON and Manifest
    payload = {
        "meta": {
            "generatedAt": datetime.utcnow().isoformat() + "Z",
            "source": "wholesaletradingsupplies.com",
            "count": len(products),
            "imagesExtracted": len(products),
            "productIdRule": "product_id = barcode + '_WTS_' + id"
        },
        "products": products
    }

    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    # Write version manifest
    manifest_path = out_json.parent / out_json.name.replace("_data.json", "_manifest.json")
    manifest = {
        "version": datetime.utcnow().strftime("%Y%m%d%H%M%S"),
        "updated_at": payload["meta"]["generatedAt"],
        "count": len(products)
    }
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    t_total = time.perf_counter() - t0
    print("\n==============================================")
    print("✅ SCRAPER COMPLETED SUCCESSFULLY")
    print(f"- Scraped products: {len(products)}")
    print(f"- JSON written: {out_json}")
    print(f"- Manifest written: {manifest_path}")
    print(f"⏱️ Total duration: {format_duration(t_total)}")
    print("==============================================\n")
    return 0

if __name__ == "__main__":
    import sys
    sys.exit(main())
