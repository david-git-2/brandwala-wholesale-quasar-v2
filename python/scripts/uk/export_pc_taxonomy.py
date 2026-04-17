#!/usr/bin/env python3
"""Export unique UK brand and category lists from pc_data.json."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.json"
DEFAULT_BRANDS_OUTPUT = ROOT_DIR / "web" / "public" / "uk" / "brands.json"
DEFAULT_CATEGORIES_OUTPUT = ROOT_DIR / "web" / "public" / "uk" / "categories.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export unique UK brand and category lists from pc_data.json.",
    )
    parser.add_argument(
        "--input",
        dest="input_path",
        default=str(DEFAULT_INPUT),
        help="Input JSON path (default: web/public/uk/pc_data.json)",
    )
    parser.add_argument(
        "--brands-output",
        dest="brands_output_path",
        default=str(DEFAULT_BRANDS_OUTPUT),
        help="Brands JSON output path (default: web/public/uk/brands.json)",
    )
    parser.add_argument(
        "--categories-output",
        dest="categories_output_path",
        default=str(DEFAULT_CATEGORIES_OUTPUT),
        help="Categories JSON output path (default: web/public/uk/categories.json)",
    )
    return parser.parse_args()


def load_products(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("products"), list):
        return payload["products"]
    if isinstance(payload, list):
        return payload
    raise ValueError("Unsupported JSON shape. Expected {'products': [...]} or a list.")


def to_text(value: Any) -> str:
    return str(value if value is not None else "").strip()


def collect_unique_values(products: list[dict[str, Any]], key: str) -> list[str]:
    seen: set[str] = set()
    values: list[str] = []
    for row in products:
        value = to_text(row.get(key, ""))
        if not value:
            continue
        normalized = value.casefold()
        if normalized in seen:
            continue
        seen.add(normalized)
        values.append(value)
    return sorted(values, key=lambda item: item.casefold())


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def build_payload(values: list[str], field_name: str, source_count: int) -> dict[str, Any]:
    return {
        "source": "pc_data.json",
        "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "count": len(values),
        "sourceProductCount": source_count,
        field_name: values,
    }


def main() -> int:
    args = parse_args()
    input_path = Path(args.input_path).expanduser().resolve()
    brands_output_path = Path(args.brands_output_path).expanduser().resolve()
    categories_output_path = Path(args.categories_output_path).expanduser().resolve()

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    with input_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    products = load_products(payload)
    brands = collect_unique_values(products, "brand")
    categories = collect_unique_values(products, "category")

    brands_payload = build_payload(brands, "brands", len(products))
    categories_payload = build_payload(categories, "categories", len(products))

    write_json(brands_output_path, brands_payload)
    write_json(categories_output_path, categories_payload)

    print(f"Input: {input_path}")
    print(f"Brands: {len(brands)} -> {brands_output_path}")
    print(f"Categories: {len(categories)} -> {categories_output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
