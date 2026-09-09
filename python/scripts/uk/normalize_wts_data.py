#!/usr/bin/env python3
"""Second-pass normalizer for UK wts_data.json payloads."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT_DIR / "python"))
from wts_excel_spec import sanitize_cell_text

DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "wts_data.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize UK WTS JSON with Pack-based minimum_quantity.",
    )
    parser.add_argument(
        "--input",
        dest="input_path",
        default=str(DEFAULT_INPUT),
        help="Input JSON path (default: web/public/uk/wts_data.json)",
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
        if key in row and row.get(key) is not None and to_text(row.get(key)) != "":
            return row.get(key)
    return default


def build_normalized_row(row: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    normalized["product_code"] = to_text(
        get_first_value(row, ["product_code", "ProdCode", "PRODUCT CODE"], "")
    )
    normalized["barcode"] = to_text(get_first_value(row, ["barcode", "Barcode", "BARCODE"], ""))
    normalized["case_size"] = max(
        1,
        to_int(
            get_first_value(row, ["case_size", "Pack", "pack", "CASE SIZE", "inner_case"], 1),
            1,
        ),
    )
    normalized["name"] = to_text(
        get_first_value(row, ["name", "Product Description", "product description", "title"], "")
    )
    normalized["price"] = to_float(
        get_first_value(row, ["price", "Each", "each", "PIECE PRICE £", "piece_price"], 0),
        0.0,
    )
    normalized["available_units"] = to_int(
        get_first_value(row, ["available_units", "Available", "available"], 0),
        0,
    )

    for optional_key, aliases in {
        "pack_price": ["pack_price", "Price", "price"],
        "outer_barcode": ["outer_barcode", "Outer Barcode", "outer barcode"],
        "outer_per_plt": ["outer_per_plt", "Pallet Qty", "pallet qty"],
        "layer_qty": ["layer_qty", "Layer Qty", "layer qty"],
    }.items():
        value = get_first_value(row, aliases, "")
        if to_text(value):
            normalized[optional_key] = sanitize_cell_text(value)

    product_id = to_text(get_first_value(row, ["product_id"], ""))
    if not product_id and normalized["barcode"] and normalized["product_code"]:
        product_id = f"{normalized['barcode']}_{normalized['product_code']}"
    normalized["product_id"] = product_id

    normalized["minimum_quantity"] = normalized["case_size"]
    normalized["source"] = to_text(get_first_value(row, ["source", "SOURCE"], "excel"))
    normalized["hazardous"] = False
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
    filtered_products = [build_normalized_row(row) for row in products]

    if isinstance(payload, dict):
        normalized_payload = dict(payload)
        normalized_payload["products"] = filtered_products
        meta = dict(normalized_payload.get("meta") or {})
        meta["count"] = len(filtered_products)
        meta["normalizedAt"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        meta["normalizedStage"] = "wts_minimum_quantity"
        meta["minimumQuantityRule"] = "minimum_quantity = Pack (case_size)"
        normalized_payload["meta"] = meta
    else:
        normalized_payload = filtered_products

    print(f"Input: {input_path}")
    print(f"Output: {output_path}")
    print(f"Rows in: {len(products)}")
    print(f"Rows out: {len(filtered_products)}")

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
