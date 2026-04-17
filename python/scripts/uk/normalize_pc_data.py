#!/usr/bin/env python3
"""Second-pass normalizer for UK pc_data.json payloads."""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize UK PC JSON with minimum_quantity and hazardous filtering.",
    )
    parser.add_argument(
        "--input",
        dest="input_path",
        default=str(DEFAULT_INPUT),
        help="Input JSON path (default: web/public/uk/pc_data.json)",
    )
    parser.add_argument(
        "--output",
        dest="output_path",
        default="",
        help="Output JSON path (default: overwrite input)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print changes without writing output.",
    )
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not write backup when overwriting input.",
    )
    return parser.parse_args()


def to_text(value: Any) -> str:
    return str(value if value is not None else "").strip()


def to_int(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(round(value))
    text = to_text(value).replace(",", "")
    if text in ("", "-", ".", "-."):
        return default
    try:
        return int(round(float(text)))
    except ValueError:
        return default


def to_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    text = to_text(value).replace(",", "")
    if text in ("", "-", ".", "-."):
        return default
    try:
        return float(text)
    except ValueError:
        return default


def load_products(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("products"), list):
        return payload["products"]
    if isinstance(payload, list):
        return payload
    raise ValueError("Unsupported JSON shape. Expected {'products': [...]} or a list.")


def get_first_value(row: dict[str, Any], keys: list[str], default: Any = "") -> Any:
    for key in keys:
        if key in row:
            return row.get(key)
    return default


def normalize_hazardous_value(value: Any) -> str:
    return to_text(value).lower().replace(" ", "")


def should_skip_row(row: dict[str, Any]) -> bool:
    hazardous_value = get_first_value(row, ["Hazardous", "hazardous"], "")
    return normalize_hazardous_value(hazardous_value) == "yes"


def compute_minimum_quantity(row: dict[str, Any]) -> int:
    sales_unit = to_text(get_first_value(row, ["sales_unit", "SALES UNIT"], "")).upper()
    outer_case = max(0, to_int(get_first_value(row, ["outer_case", "OUTER CASE"], 0), 0))
    inner_case = max(0, to_int(get_first_value(row, ["inner_case", "INNER CASE"], 0), 0))

    if sales_unit == "CASE":
        return outer_case if outer_case > 0 else 1
    if sales_unit == "INNER":
        return 6 if inner_case < 6 else inner_case
    return 1


def format_optional_expire_date(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.date().isoformat()
    text = to_text(value)
    return text


def build_normalized_row(row: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    normalized["product_code"] = to_text(get_first_value(row, ["product_code", "PRODUCT CODE"], ""))
    normalized["barcode"] = to_text(get_first_value(row, ["barcode", "BARCODE"], ""))
    normalized["case_size"] = max(
        1,
        to_int(get_first_value(row, ["case_size", "CASE SIZE", "INNER CASE", "inner_case"], 1), 1),
    )
    normalized["name"] = to_text(get_first_value(row, ["name", "DESCRIPTION"], ""))
    normalized["price"] = to_float(get_first_value(row, ["price", "PIECE PRICE £", "piece_price"], 0), 0.0)
    normalized["country_of_origin"] = to_text(
        get_first_value(row, ["country_of_origin", "COUNTRY OF ORIGIN"], "")
    )
    normalized["brand"] = to_text(get_first_value(row, ["brand", "BRAND"], ""))
    normalized["category"] = to_text(get_first_value(row, ["category", "CATEGORY"], ""))
    normalized["available_units"] = to_text(
        get_first_value(row, ["available_units", "AVAILABLE UNITS"], "")
    )
    normalized["inner_case"] = to_text(get_first_value(row, ["inner_case", "INNER CASE"], ""))
    normalized["outer_case"] = to_text(get_first_value(row, ["outer_case", "OUTER CASE"], ""))
    normalized["outer_per_plt"] = to_text(get_first_value(row, ["outer_per_plt", "OUTER PER PLT"], ""))
    normalized["tariff_code"] = to_text(get_first_value(row, ["tariff_code", "TARIFF CODE"], ""))
    normalized["languages"] = to_text(get_first_value(row, ["languages", "LANGUAGES"], ""))
    normalized["batch_code_manufacture_date"] = to_text(
        get_first_value(
            row,
            ["batch_code_manufacture_date", "BATCH CODE / MANUFACTURE DATE"],
            "",
        )
    )
    normalized["sales_unit"] = to_text(get_first_value(row, ["sales_unit", "SALES UNIT"], ""))
    image_value = get_first_value(row, ["image", "IMAGE"], None)
    if image_value is not None:
        normalized["image"] = image_value
    image_url_value = get_first_value(row, ["imageUrl", "image_url"], None)
    if image_url_value is not None:
        normalized["imageUrl"] = image_url_value
    normalized["expire_date"] = format_optional_expire_date(
        get_first_value(row, ["expire_date", "expiry_date", "EXPIRY DATE"], "")
    )
    product_id = to_text(get_first_value(row, ["product_id"], ""))
    if not product_id and normalized["barcode"] and normalized["product_code"]:
        product_id = f"{normalized['barcode']}_{normalized['product_code']}"
    normalized["product_id"] = product_id
    normalized["minimum_quantity"] = compute_minimum_quantity(normalized)
    return normalized


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def main() -> int:
    args = parse_args()
    input_path = Path(args.input_path).expanduser().resolve()
    output_path = Path(args.output_path).expanduser().resolve() if args.output_path else input_path

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    with input_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    products = load_products(payload)
    filtered_products: list[dict[str, Any]] = []
    removed_rows = 0
    updated_rows = 0
    samples: list[tuple[str, int, int]] = []

    for row in products:
        if should_skip_row(row):
            removed_rows += 1
            continue

        next_row = build_normalized_row(row)
        next_minimum = next_row["minimum_quantity"]
        prev_minimum = row.get("minimum_quantity")
        filtered_products.append(next_row)

        if prev_minimum != next_minimum:
            updated_rows += 1
            if len(samples) < 8:
                samples.append((to_text(next_row.get("product_code") or next_row.get("PRODUCT CODE")), to_int(prev_minimum, 0), next_minimum))

    normalized_payload: Any
    if isinstance(payload, dict):
        normalized_payload = dict(payload)
        normalized_payload["products"] = filtered_products
        meta = dict(normalized_payload.get("meta") or {})
        meta["count"] = len(filtered_products)
        meta["normalizedAt"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        meta["normalizedStage"] = "minimum_quantity"
        meta["removedHazardousRows"] = removed_rows
        meta["minimumQuantityRule"] = "CASE -> outer_case; INNER -> max(inner_case, 6); otherwise 1"
        normalized_payload["meta"] = meta
    else:
        normalized_payload = filtered_products

    print(f"Input: {input_path}")
    print(f"Output: {output_path}")
    print(f"Rows in: {len(products)}")
    print(f"Rows out: {len(filtered_products)}")
    print(f"Rows removed (hazardous YES): {removed_rows}")
    print(f"Rows updated (minimum_quantity set): {updated_rows}")
    if samples:
        print("\nSample updates:")
        for idx, (product_code, before, after) in enumerate(samples, start=1):
            print(f"{idx}. {product_code or '-'}: minimum_quantity {before} -> {after}")

    if args.dry_run:
        print("\nDry run: no file written.")
        return 0

    if output_path == input_path and not args.no_backup:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = input_path.with_suffix(input_path.suffix + f".bak.{stamp}")
        shutil.copy2(input_path, backup_path)
        print(f"Backup: {backup_path}")

    write_json(output_path, normalized_payload)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
