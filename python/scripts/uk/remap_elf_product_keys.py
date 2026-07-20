#!/usr/bin/env python3
"""Remap existing ELF products' barcode + product_code to match scraped elf_data.json.

Matches DB rows (vendor ELF) to scrape by model code in product_code / name / image URL,
then UPDATEs only barcode and product_code so a later sync upserts instead of inserting duplicates.

Default: dry-run. Pass --apply to write.
"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse

try:
    import requests
except ModuleNotFoundError:  # pragma: no cover
    requests = None  # type: ignore[assignment]

ROOT_DIR = Path(__file__).resolve().parents[3]
WEB_ENV_FILE = ROOT_DIR / "web" / ".env"
ROOT_ENV_FILE = ROOT_DIR / ".env"
DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "elf_data.json"

VENDOR_CODE = "ELF"
VENDOR_ID = 5
MARKET_CODE = "GB"
DEFAULT_TENANT_ID = 10

# Strip common ELF image / SKU prefixes when comparing model codes
PREFIX_RE = re.compile(
    r"^(RE|REV|BRN|WA|FIRE|KE|PH|BA|OM|RH|SAL|PAN|DEL|GF|HO|KR|OR|PR|SO|TO|TG|TR|VI|WW)[-_]?",
    re.IGNORECASE,
)
MODEL_TOKEN_RE = re.compile(r"[A-Z0-9][A-Z0-9._/-]{2,}", re.IGNORECASE)
TRAILING_MODEL_RE = re.compile(
    r"(?:^|[\s\-–—])([A-Z]{0,6}[-_]?\d[\w./-]{1,}|[A-Z]{2,}[-_]?\d[\w./-]*)\s*$",
    re.IGNORECASE,
)


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


def to_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def normalize_code(value: str) -> str:
    text = to_text(value).upper().replace(" ", "")
    text = text.replace("\\", "/")
    return text


def strip_prefix(code: str) -> str:
    text = normalize_code(code)
    return PREFIX_RE.sub("", text)


def image_basename(url: str) -> str:
    if not url:
        return ""
    path = unquote(urlparse(url).path)
    name = Path(path).stem
    return normalize_code(name)


def extract_trailing_model(name: str) -> str:
    match = TRAILING_MODEL_RE.search(to_text(name))
    if not match:
        return ""
    return normalize_code(match.group(1))


def candidate_codes_from_db_row(row: dict[str, Any]) -> list[str]:
    codes: list[str] = []
    product_code = to_text(row.get("product_code"))
    name = to_text(row.get("name"))
    image_url = to_text(row.get("image_url"))

    if product_code and not product_code.upper().startswith("ELF_"):
        codes.append(normalize_code(product_code))
        stripped = strip_prefix(product_code)
        if stripped and stripped != normalize_code(product_code):
            codes.append(stripped)

    trailing = extract_trailing_model(name)
    if trailing:
        codes.append(trailing)
        stripped = strip_prefix(trailing)
        if stripped:
            codes.append(stripped)

    # Tokens from name that look like model numbers (contain a digit)
    for token in MODEL_TOKEN_RE.findall(name.upper().replace(" ", "")):
        if any(ch.isdigit() for ch in token) and len(token) >= 3:
            codes.append(normalize_code(token))

    base = image_basename(image_url)
    if base:
        codes.append(base)
        stripped = strip_prefix(base)
        if stripped:
            codes.append(stripped)

    # Dedupe preserving order
    seen: set[str] = set()
    out: list[str] = []
    for c in codes:
        if not c or c in seen:
            continue
        # Skip ultra-generic short tokens
        if len(c) < 3:
            continue
        seen.add(c)
        out.append(c)
    return out


def scrape_index_keys(product: dict[str, Any]) -> list[str]:
    keys: list[str] = []
    name = to_text(product.get("name"))
    image_url = to_text(product.get("imageUrl") or product.get("image_url"))
    product_code = to_text(product.get("product_code"))

    if product_code:
        keys.append(normalize_code(product_code))

    trailing = extract_trailing_model(name)
    if trailing:
        keys.append(trailing)
        keys.append(strip_prefix(trailing))

    for token in MODEL_TOKEN_RE.findall(name.upper()):
        tok = normalize_code(token)
        if any(ch.isdigit() for ch in tok) and len(tok) >= 3:
            keys.append(tok)
            keys.append(strip_prefix(tok))

    # Also match spaced-stripped name tokens like "RVDR5222VUK ROSE"
    compact = normalize_code(name)
    for token in MODEL_TOKEN_RE.findall(compact):
        if any(ch.isdigit() for ch in token) and len(token) >= 3:
            keys.append(normalize_code(token))

    base = image_basename(image_url)
    if base:
        keys.append(base)
        keys.append(strip_prefix(base))

    seen: set[str] = set()
    out: list[str] = []
    for k in keys:
        if not k or k in seen or len(k) < 3:
            continue
        seen.add(k)
        out.append(k)
    return out


class SupabaseRestClient:
    def __init__(self, base_url: str, api_key: str) -> None:
        if requests is None:
            raise RuntimeError("requests is required. Install python deps via scripts/run-python-elf.sh")
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

    def update_row_by_id(self, table: str, row_id: int, payload: dict[str, Any]) -> None:
        headers = dict(self.headers)
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = "return=minimal"
        params = {"id": f"eq.{row_id}"}
        resp = requests.patch(self._url(table), headers=headers, params=params, json=payload, timeout=120)
        if not resp.ok:
            raise RuntimeError(f"UPDATE {table} id={row_id} failed ({resp.status_code}): {resp.text}")


def fetch_elf_products(client: SupabaseRestClient, tenant_id: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    offset = 0
    limit = 1000
    while True:
        params: dict[str, Any] = {
            "select": "id,tenant_id,product_code,barcode,name,image_url,vendor_code,vendor_id,market_code",
            "vendor_code": f"eq.{VENDOR_CODE}",
            "vendor_id": f"eq.{VENDOR_ID}",
            "market_code": f"eq.{MARKET_CODE}",
            "tenant_id": f"eq.{tenant_id}",
            "order": "id.asc",
            "limit": str(limit),
            "offset": str(offset),
        }
        batch = client.get_rows("products", params)
        rows.extend(batch)
        if len(batch) < limit:
            break
        offset += limit
    return rows


def load_scraped(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        products = payload.get("products") or []
    elif isinstance(payload, list):
        products = payload
    else:
        raise ValueError(f"Unexpected scrape JSON shape in {path}")
    if not isinstance(products, list):
        raise ValueError("products must be a list")
    return products


def build_scrape_indexes(
    scraped: list[dict[str, Any]],
) -> tuple[dict[str, list[dict[str, Any]]], dict[str, dict[str, Any]]]:
    by_key: dict[str, list[dict[str, Any]]] = {}
    by_product_code: dict[str, dict[str, Any]] = {}
    for product in scraped:
        pc = normalize_code(to_text(product.get("product_code")))
        if pc:
            by_product_code[pc] = product
        for key in scrape_index_keys(product):
            by_key.setdefault(key, []).append(product)
    return by_key, by_product_code


def match_row(
    row: dict[str, Any],
    by_key: dict[str, list[dict[str, Any]]],
    by_product_code: dict[str, dict[str, Any]],
) -> tuple[dict[str, Any] | None, str]:
    """Return (scraped_product, reason)."""
    current_code = normalize_code(to_text(row.get("product_code")))

    # Already remapped to ELF_{id}
    if current_code.startswith("ELF_"):
        hit = by_product_code.get(current_code)
        if hit:
            return hit, "already_elf_code"
        return None, "elf_code_not_in_scrape"

    candidates: dict[int, tuple[dict[str, Any], str]] = {}
    for code in candidate_codes_from_db_row(row):
        hits = by_key.get(code) or []
        # Prefer exact unique hits
        unique_hits: list[dict[str, Any]] = []
        seen_ids: set[str] = set()
        for h in hits:
            hid = to_text(h.get("product_code"))
            if hid in seen_ids:
                continue
            seen_ids.add(hid)
            unique_hits.append(h)
        if len(unique_hits) == 1:
            p = unique_hits[0]
            # Use scrape product_code numeric id as dict key stability
            pid = id(p)
            if pid not in candidates:
                candidates[pid] = (p, f"code:{code}")
        elif len(unique_hits) > 1:
            # Ambiguous for this code — try longer/more specific later; skip this code
            continue

    if len(candidates) == 1:
        product, reason = next(iter(candidates.values()))
        return product, reason
    if len(candidates) > 1:
        return None, "ambiguous_multi_code"
    return None, "no_match"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remap ELF product barcode/product_code from scraped JSON (update only).",
    )
    parser.add_argument(
        "--input",
        default=str(DEFAULT_INPUT),
        help="Scraped ELF JSON path (default: web/public/uk/elf_data.json)",
    )
    parser.add_argument(
        "--tenant-id",
        type=int,
        default=DEFAULT_TENANT_ID,
        help=f"Tenant id (default: {DEFAULT_TENANT_ID})",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write updates to Supabase (default is dry-run).",
    )
    parser.add_argument(
        "--report",
        default="",
        help="Optional path to write JSON report of matches/unmatched.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        raise SystemExit(f"Scrape file not found: {input_path}")

    supabase_url = to_text(os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL"))
    supabase_key = to_text(
        os.getenv("SUPABASE_SECRET_KEY")
        or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SERVICE_ROLE_KEY")
    )
    if not supabase_url or not supabase_key:
        raise SystemExit("Missing SUPABASE_URL / SUPABASE_SECRET_KEY in env.")

    client = SupabaseRestClient(supabase_url, supabase_key)
    scraped = load_scraped(input_path)
    by_key, by_product_code = build_scrape_indexes(scraped)
    db_rows = fetch_elf_products(client, args.tenant_id)

    print(f"Tenant {args.tenant_id} | vendor {VENDOR_CODE} (id={VENDOR_ID}) | market {MARKET_CODE}")
    print(f"DB products: {len(db_rows)}")
    print(f"Scraped products: {len(scraped)}")
    print(f"Mode: {'APPLY' if args.apply else 'DRY-RUN'}")

    planned: list[dict[str, Any]] = []
    unmatched: list[dict[str, Any]] = []
    skipped_same: list[dict[str, Any]] = []
    ambiguous: list[dict[str, Any]] = []

    used_scrape_codes: set[str] = set()

    for row in db_rows:
        matched, reason = match_row(row, by_key, by_product_code)
        row_id = int(row["id"])
        old_code = to_text(row.get("product_code"))
        old_barcode = to_text(row.get("barcode"))

        if matched is None:
            entry = {
                "id": row_id,
                "name": to_text(row.get("name")),
                "product_code": old_code,
                "barcode": old_barcode or None,
                "reason": reason,
            }
            if reason == "ambiguous_multi_code":
                ambiguous.append(entry)
            else:
                unmatched.append(entry)
            continue

        new_code = to_text(matched.get("product_code"))
        new_barcode = to_text(matched.get("barcode"))
        if not new_code or not new_barcode:
            unmatched.append(
                {
                    "id": row_id,
                    "name": to_text(row.get("name")),
                    "product_code": old_code,
                    "reason": "scrape_missing_keys",
                }
            )
            continue

        scrape_key = normalize_code(new_code)
        if scrape_key in used_scrape_codes:
            ambiguous.append(
                {
                    "id": row_id,
                    "name": to_text(row.get("name")),
                    "product_code": old_code,
                    "matched_product_code": new_code,
                    "reason": "scrape_already_claimed",
                }
            )
            continue

        if old_code == new_code and old_barcode == new_barcode:
            skipped_same.append(
                {
                    "id": row_id,
                    "product_code": old_code,
                    "barcode": old_barcode,
                    "reason": reason,
                }
            )
            used_scrape_codes.add(scrape_key)
            continue

        used_scrape_codes.add(scrape_key)
        planned.append(
            {
                "id": row_id,
                "name": to_text(row.get("name")),
                "old_product_code": old_code or None,
                "old_barcode": old_barcode or None,
                "new_product_code": new_code,
                "new_barcode": new_barcode,
                "scrape_name": to_text(matched.get("name")),
                "match_reason": reason,
            }
        )

    print(f"\nPlanned updates: {len(planned)}")
    print(f"Already correct: {len(skipped_same)}")
    print(f"Unmatched: {len(unmatched)}")
    print(f"Ambiguous/skipped: {len(ambiguous)}")

    for item in planned[:15]:
        print(
            f"  id={item['id']}: "
            f"{item['old_product_code']!r}/{item['old_barcode']!r} "
            f"-> {item['new_product_code']}/{item['new_barcode']} "
            f"[{item['match_reason']}]"
        )
    if len(planned) > 15:
        print(f"  ... and {len(planned) - 15} more")

    if unmatched:
        print("\nUnmatched samples:")
        for item in unmatched[:10]:
            print(f"  id={item['id']}: {item['product_code']!r} | {item['name'][:60]}")

    if args.apply and planned:
        updated = 0
        for item in planned:
            client.update_row_by_id(
                "products",
                int(item["id"]),
                {
                    "product_code": item["new_product_code"],
                    "barcode": item["new_barcode"],
                },
            )
            updated += 1
            if updated % 25 == 0 or updated == len(planned):
                print(f"Updated {updated}/{len(planned)}")
        print(f"\nApplied {updated} updates.")
    elif args.apply:
        print("\nNothing to apply.")
    else:
        print("\nDry-run only. Re-run with --apply to write.")

    if args.report:
        report_path = Path(args.report).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(
                {
                    "tenant_id": args.tenant_id,
                    "mode": "apply" if args.apply else "dry-run",
                    "planned": planned,
                    "skipped_same": skipped_same,
                    "unmatched": unmatched,
                    "ambiguous": ambiguous,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"Report: {report_path}")


if __name__ == "__main__":
    main()
