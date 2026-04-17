#!/usr/bin/env python3
"""Export UK PC product rows from pc_data.json into a flat CSV file."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.json"
DEFAULT_OUTPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.csv"
EXCLUDED_HEADERS = {
    "case_size",
    "inner_case",
    "outer_case",
    "outer_per_plt",
    "sales_unit",
    "product_id",
}
HEADER_RENAMES = {
    "minimum_quantity": "minimum_order_quantity",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export UK PC product rows from pc_data.json to CSV.",
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
        default=str(DEFAULT_OUTPUT),
        help="Output CSV path (default: web/public/uk/pc_data.csv)",
    )
    return parser.parse_args()


def load_products(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("products"), list):
        return payload["products"]
    if isinstance(payload, list):
        return payload
    raise ValueError("Unsupported JSON shape. Expected {'products': [...]} or a list.")


def collect_headers(products: list[dict[str, Any]]) -> list[str]:
    headers: list[str] = []
    seen: set[str] = set()
    for row in products:
        for key in row.keys():
            if key in EXCLUDED_HEADERS:
                continue
            header_name = HEADER_RENAMES.get(key, key)
            if header_name not in seen:
                seen.add(header_name)
                headers.append(header_name)
    return headers


def main() -> int:
    args = parse_args()
    input_path = Path(args.input_path).expanduser().resolve()
    output_path = Path(args.output_path).expanduser().resolve()

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    with input_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    products = load_products(payload)
    headers = collect_headers(products)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers, extrasaction="ignore")
        writer.writeheader()
        for row in products:
            output_row: dict[str, Any] = {}
            for key in headers:
                source_key = next((src for src, renamed in HEADER_RENAMES.items() if renamed == key), key)
                output_row[key] = row.get(source_key, "")
            writer.writerow(output_row)

    print(f"Wrote {len(products)} rows to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
