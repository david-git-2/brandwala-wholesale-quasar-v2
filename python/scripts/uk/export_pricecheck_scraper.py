#!/usr/bin/env python3
"""Scrapes shop.pricecheck.uk.com using Playwright, extracts complete product data including
pricing, barcodes, SKU codes, case sizes, stock levels, and brands, and saves the data to a JSON file."""

import os
import re
import json
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright

# Paths relative to this script
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parents[2]
WEB_ENV_FILE = ROOT_DIR / "web" / ".env"
ROOT_ENV_FILE = ROOT_DIR / ".env"

DEFAULT_OUT_JSON = ROOT_DIR / "web" / "public" / "uk" / "pc_scraped_data.json"
DEFAULT_OUT_MANIFEST = ROOT_DIR / "web" / "public" / "uk" / "pc_scraped_manifest.json"

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
            os.environ[key] = value

load_env_file(WEB_ENV_FILE)
load_env_file(ROOT_ENV_FILE)

PC_EMAIL = os.environ.get("PC_EMAIL")
PC_PASSWORD = os.environ.get("PC_PASSWORD")

if not PC_EMAIL or not PC_PASSWORD or PC_EMAIL == "your_email@example.com":
    print("⚠️ WARNING: No valid credentials found in .env.")
    print("Will skip login and scrape without prices to demonstrate data structure.")
    has_credentials = False
else:
    has_credentials = True

COMMON_BRANDS = [
    "COCO & EVE", "BIOTHERM", "BABOR", "ADIDAS", "CALVIN KLEIN", "AVEENO", 
    "AIR WICK", "AIRPURE", "ALBERTO BALSAM", "ALWAYS", "ANIMOLOGY", "ASEVI", 
    "ASTONISH", "BATISTE", "BEAUTY FORMULAS", "BIC", "BIO OIL", "BIORE", 
    "BONDI SANDS", "BOURJOIS", "BRITNEY SPEARS", "BULLDOG", "BURBERRY", 
    "BYPHASE", "CANTU", "CAREX", "CARMEX", "CERAVE", "CETAPHIL", "CHUPA CHUPS", 
    "CLINIQUE", "COLGATE", "CREST", "DANY", "DAVE", "DAVIDOFF", "DENTYL", 
    "DERMACOL", "DETTOL", "DIESEL", "DOMESTOS", "DOVE", "DR TEALS", "DR. JART+", 
    "ECOTOOLS", "ELIZABETH ARDEN", "ELVIVE", "ESSIE", "EUCERIN", "FA", 
    "FAIRY", "FÉBREZE", "FENTY BEAUTY", "FUDGE", "GARNIER", "GILLETTE", 
    "GLISS", "GOT2B", "GUCCI", "HEAD & SHOULDERS", "HERBAL ESSENCES", 
    "HUGO BOSS", "INKEY LIST", "IPANA", "JIL SANDER", "JOHN FRIEDA", 
    "JOHNSON & JOHNSON", "JOHNSON'S", "JOOP", "K18", "LA ROCHE-POSAY", 
    "LANEIGE", "LENOR", "L'OREAL", "L'ORÉAL", "LUXURY", "MARVIS", "MAX FACTOR", 
    "MAYBELLINE", "METHOD", "MILANO", "MIST", "MONTBLANC", "MUGHER", "NATIVE", 
    "NEUTROGENA", "NIVEA", "NYX", "OATY", "OGX", "OLAPLEX", "OLD SPICE", 
    "OLAY", "ORAL-B", "PALMOLIVE", "PAMPERS", "PANTENE", "PEARLS", "PEARS", 
    "PILGRIM", "PINAUD", "REVLON", "RIMMEL", "SALLY HANSEN", "SCHWARZKOPF", 
    "SENSODYNE", "SHEA MOISTURE", "SHISEIDO", "SIMPLE", "SUDOCREM", "SUMMER BEAUTY", 
    "SUNDOWN", "TAMPAX", "THE ORDINARY", "TRESEMME", "TRESEMMÉ", "VALENTINO", 
    "VAPO", "VASELINE", "VICKS", "VICTORIA'S SECRET", "WELEDA", "WHISPER", "WILKINSON"
]

def main():
    out_json = Path(DEFAULT_OUT_JSON)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    
    unique_products = {}
    
    with sync_playwright() as p:
        # Launch browser
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        # 3 minutes timeout for standard navigations to make script resilient
        context.set_default_navigation_timeout(60000)
        page = context.new_page()

        if has_credentials:
            print("🌐 Navigating to login page...")
            page.goto("https://shop.pricecheck.uk.com/customer/account/login/")
            
            print("🔐 Logging in...")
            page.fill("#email", PC_EMAIL)
            page.fill("#pass", PC_PASSWORD)
            page.click("#customer-login-form button[type='submit']")
            
            print("⏳ Waiting for login to complete...")
            try:
                page.wait_for_url("**/customer/account/**", timeout=15000)
                print("✅ Login successful!")
            except Exception as e:
                print("⚠️ Login timeout or redirect issue. Checking if we are logged in anyway...")
                if page.locator(".logged-in").is_visible() or "account" in page.url:
                    print("✅ Login verified by element/URL.")
                else:
                    print(f"❌ Login failed. Current URL: {page.url}")
                    page.screenshot(path="login_failed.png")
                    browser.close()
                    exit(1)

        # 1. PRE-SCRAPE BRANDS
        brands_list = list(COMMON_BRANDS)
        try:
            print("🏷️ Navigating to brands page to build index...")
            page.goto("https://shop.pricecheck.uk.com/brands")
            brand_links = page.query_selector_all("a")
            scraped_brands = []
            for l in brand_links:
                try:
                    text = l.inner_text().strip()
                    # e.g., "ADIDAS (38)"
                    m = re.search(r'^(.*?)\s*\((\d+)\)$', text)
                    if m:
                        brand_name = m.group(1).strip()
                        if brand_name and not brand_name.isdigit() and len(brand_name) > 1:
                            scraped_brands.append(brand_name)
                except:
                    continue
            if scraped_brands:
                # Merge and keep unique values
                brands_list = list(set(brands_list + scraped_brands))
                print(f"✅ Successfully indexed {len(scraped_brands)} brands from website (Total list size: {len(brands_list)})")
            else:
                print("⚠️ No brands found on /brands page. Falling back to default list.")
        except Exception as exc:
            print(f"⚠️ Failed to scrape brands page: {exc}. Falling back to default list.")
            
        # Sort brands by length descending to match longest brand names first
        brands_list = sorted(brands_list, key=len, reverse=True)

        # 2. DISCOVER CATEGORIES
        categories = []
        try:
            print("🔍 Discovering categories from homepage menu...")
            page.goto("https://shop.pricecheck.uk.com/")
            time.sleep(2) # let page fully load
            
            nav_links = page.query_selector_all("nav.navigation a")
            seen_urls = set()
            for l in nav_links:
                try:
                    url = l.get_attribute("href")
                    text = l.inner_text().strip()
                    if not url or not url.startswith("http"):
                        continue
                    parsed = urlparse(url)
                    path = parsed.path.strip("/")
                    if not path:
                        continue
                        
                    # Skip utilities / accounts / non-product lists
                    if any(k in path for k in ["customer", "contact", "about", "privacy", "terms", "shipping", "returns", "cookies", "brands", "new-lines"]):
                        continue
                        
                    # Filter for depth-1 categories (e.g. shop.pricecheck.uk.com/beauty-skincare)
                    segments = [s for s in path.split("/") if s]
                    if len(segments) != 1:
                        continue
                        
                    cat_name = text.replace("See all ", "").replace("Shop ", "").strip()
                    if not cat_name:
                        continue
                        
                    if url not in seen_urls:
                        seen_urls.add(url)
                        categories.append((cat_name, url))
                except:
                    continue
            print(f"✅ Discovered {len(categories)} categories: {[cat[0] for cat in categories]}")
        except Exception as exc:
            print(f"❌ Error discovering categories: {exc}")
            # Minimal fallback if homepage discovery failed completely
            categories = [("Beauty & Skincare", "https://shop.pricecheck.uk.com/beauty-skincare")]

        # 3. CRAWL CATEGORIES
        for cat_name, cat_url in categories:
            print(f"\n📂 Scraping category: {cat_name} ({cat_url})")
            p_idx = 1
            max_pages = 60 # safety limit
            
            while p_idx <= max_pages:
                page_url = f"{cat_url}?p={p_idx}"
                print(f"  📄 Loading page {p_idx}: {page_url}")
                
                try:
                    page.goto(page_url)
                    
                    # Wait for items to load
                    try:
                        page.wait_for_selector(".product-item", timeout=12000)
                    except:
                        print("  📭 No product grid selector found. Reached end of category.")
                        break
                        
                    # Double-check redirects (if we went past max page, Magento sometimes redirects to page 1)
                    current_url = page.url
                    if p_idx > 1 and f"p={p_idx}" not in current_url:
                        # Check if it loaded page 1 instead
                        if "p=" not in current_url or "p=1" in current_url:
                            print("  🔄 Redirected to first page or other page. Pagination finished.")
                            break
                    
                    product_elements = page.query_selector_all(".product-item")
                    page_item_count = len(product_elements)
                    print(f"  📦 Found {page_item_count} products on page {p_idx}.")
                    
                    if page_item_count == 0:
                        break
                        
                    for item in product_elements:
                        try:
                            # 1. Title and URL
                            title_elem = item.query_selector(".product-item-link")
                            if not title_elem:
                                continue
                            title = title_elem.inner_text().strip()
                            url = title_elem.get_attribute("href") or ""
                            
                            # 2. Extract full card text for regex-based fallbacks
                            card_text = item.inner_text()
                            
                            # Helper function to read from dialog table cleanly
                            def get_dd_val(selector):
                                try:
                                    el = item.query_selector(selector)
                                    return el.inner_text().strip() if el else ""
                                except:
                                    return ""
                                    
                            # 3. SKU / Product Code
                            sku = get_dd_val("dt:has-text('SKU') + dd")
                            if not sku:
                                sku_el = item.query_selector(".text-xs.text-gray-600")
                                if sku_el:
                                    sku = sku_el.inner_text().strip()
                            if not sku:
                                # Regex fallback
                                lines = [l.strip() for l in card_text.split("\n") if l.strip()]
                                if len(lines) > 1:
                                    sku_cand = lines[1]
                                    if not any(k in sku_cand.lower() for k in ["ean:", "size:", "qty", "add", "£"]):
                                        sku = sku_cand
                            sku = sku.strip()
                            
                            # 4. Barcode (EAN)
                            barcode = get_dd_val("dt:has-text('Barcode') + dd")
                            if not barcode:
                                m = re.search(r'EAN:\s*(\d+)', card_text, re.IGNORECASE)
                                barcode = m.group(1) if m else ""
                            barcode = barcode.strip()
                            
                            # Skip if neither SKU nor Barcode is present
                            if not sku and not barcode:
                                continue
                                
                            # 5. Inner Size / Case Size
                            inner_qty = get_dd_val("dt:has-text('Inner Qty') + dd") or get_dd_val("dt:has-text('Inner Size') + dd")
                            if not inner_qty:
                                m = re.search(r'Inner\s+(?:Size|Qty):\s*(\d+)', card_text, re.IGNORECASE)
                                inner_qty = m.group(1) if m else "1"
                            try:
                                case_size = int(inner_qty)
                            except:
                                case_size = 1
                                
                            # 6. Outer Size
                            outer_qty = get_dd_val("dt:has-text('Outer Qty') + dd") or get_dd_val("dt:has-text('Outer Size') + dd")
                            if not outer_qty:
                                m = re.search(r'Outer\s+(?:Size|Qty):\s*(\d+)', card_text, re.IGNORECASE)
                                outer_qty = m.group(1) if m else ""
                            try:
                                outer_case = int(outer_qty) if outer_qty else 1
                            except:
                                outer_case = 1
                                
                            # 7. Outers Per Pallet
                            outer_per_plt = get_dd_val("dt:has-text('Outers Per Pallet') + dd")
                            
                            # 8. Available Units
                            qty_str = ""
                            m = re.search(r'Qty\s+Available:\s*(\d+)', card_text, re.IGNORECASE)
                            if m:
                                qty_str = m.group(1)
                            try:
                                available_units = int(qty_str) if qty_str else 0
                            except:
                                available_units = 0
                                
                            # 9. Price (Unit Price)
                            price_val = 0.0
                            # Try unit price regex
                            price_match = re.search(r'£\s*([\d\.,]+)\s*/unit', card_text, re.IGNORECASE)
                            if not price_match:
                                price_match = re.search(r'£\s*([\d\.,]+)\s*/piece', card_text, re.IGNORECASE)
                            if price_match:
                                try:
                                    price_val = float(price_match.group(1).replace(",", ""))
                                except:
                                    pass
                            if price_val == 0.0:
                                # Fallback: parse price element
                                price_elem = item.query_selector(".price")
                                if price_elem:
                                    price_text = price_elem.inner_text().strip()
                                    price_str = price_text.replace("£", "").replace(",", "")
                                    price_parts = price_str.split()
                                    if price_parts:
                                        try:
                                            price_val = float(price_parts[-1])
                                        except:
                                            pass
                                            
                            # 10. Image URL
                            img_elem = item.query_selector("img.product-image-photo")
                            img_url = img_elem.get_attribute("src") if img_elem else ""
                            
                            # 11. Brand resolution
                            brand = ""
                            title_upper = title.upper()
                            for b in brands_list:
                                if title_upper.startswith(b.upper()):
                                    brand = b
                                    break
                            if not brand:
                                words = title.split()
                                if words:
                                    brand = words[0]
                                    if len(words) > 1 and words[1] not in ["&", "and", "with", "for", "in", "on", "of", "to"]:
                                        brand = f"{words[0]} {words[1]}"
                                        
                            # 12. Identifiers
                            bc_clean = re.sub(r"[^\w\-\.]+", "_", barcode) if barcode else ""
                            pc_clean = re.sub(r"[^\w\-\.]+", "_", sku) if sku else ""
                            if not bc_clean:
                                bc_clean = f"NO_BARCODE_{pc_clean}"
                            if not pc_clean:
                                pc_clean = f"NO_CODE_{bc_clean}"
                                
                            product_id = f"{bc_clean}_{pc_clean}".strip("_")
                            image_key = f"{bc_clean}__{pc_clean}".strip("_")
                            
                            p_key = (barcode.upper(), sku.upper())
                            
                            # Add product details matching data schema
                            product_data = {
                                "title": title,
                                "name": title,
                                "price": price_val,
                                "image": img_url,
                                "imageUrl": img_url,
                                "imageKey": image_key,
                                "url": url,
                                "product_id": product_id,
                                "barcode": barcode,
                                "product_code": sku,
                                "case_size": case_size,
                                "outer_case": outer_case,
                                "outer_per_plt": outer_per_plt,
                                "available_units": available_units,
                                "brand": brand,
                                "category": cat_name,
                                "tenant_id": 10,
                                "vendor_id": 3,
                                "source": "website",
                                "hazardous": None
                            }
                            
                            # Deduplicate/update: if product exists, keep it or update if brand/barcode gets better
                            unique_products[p_key] = product_data
                            
                        except Exception as e:
                            print(f"  ⚠️ Error parsing card: {e}")
                            
                    print(f"  📈 Running total of unique products scraped: {len(unique_products)}")
                    
                except Exception as exc:
                    print(f"  ❌ Error loading page {p_idx}: {exc}")
                    
                p_idx += 1
                time.sleep(1) # brief polite pause between pages
                
        browser.close()

    # Convert unique products dict to list
    products = list(unique_products.values())
    
    # Save data
    payload = {
        "meta": {
            "generatedAt": datetime.utcnow().isoformat() + "Z",
            "source": "shop.pricecheck.uk.com",
            "count": len(products),
        },
        "products": products
    }

    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    # Write version manifest
    manifest_path = Path(DEFAULT_OUT_MANIFEST)
    manifest = {
        "version": datetime.utcnow().strftime("%Y%m%d%H%M%S"),
        "updated_at": payload["meta"]["generatedAt"],
        "count": len(products)
    }
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Scraped {len(products)} products. Saved to {out_json}")
    print(f"✅ Manifest written to {manifest_path}")

if __name__ == "__main__":
    main()
