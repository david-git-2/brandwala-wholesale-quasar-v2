#!/usr/bin/env python3
"""Remove VAT markers from product name fields in JSON product data."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_INPUT = ROOT_DIR / "web" / "public" / "uk" / "pc_data.json"

VAT_IN_PARENS_RE = re.compile(r"\s*\((?=[^)]*\bVAT\b)[^)]*\)\s*", re.IGNORECASE)
TRAILING_VAT_RE = re.compile(
    r"\s*(?:[-|:/])?\s*(?:\d+(?:\.\d+)?\s*%?\s*)?\bVAT\b(?:\s*FREE)?\s*$",
    re.IGNORECASE,
)
MULTISPACE_RE = re.compile(r"\s{2,}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Clean VAT text from product names in JSON data.",
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
        "--fields",
        default="name",
        help="Comma-separated string fields to clean (default: name)",
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


def clean_vat_text(value: Any) -> tuple[Any, bool]:
    if not isinstance(value, str):
        return value, False

    has_vat_pattern = bool(
        VAT_IN_PARENS_RE.search(value) or TRAILING_VAT_RE.search(value),
    )
    if not has_vat_pattern:
        return value, False

    original = value
    cleaned = VAT_IN_PARENS_RE.sub(" ", value)
    cleaned = TRAILING_VAT_RE.sub("", cleaned)
    cleaned = MULTISPACE_RE.sub(" ", cleaned).strip()

    # Safety: never collapse a name to empty after VAT cleanup.
    if original.strip() and not cleaned:
        return original, False

    return cleaned, cleaned != original


def load_products(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("products"), list):
        return payload["products"]
    if isinstance(payload, list):
        return payload
    raise ValueError("Unsupported JSON shape. Expected {'products': [...]} or a list.")


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def main() -> int:
    args = parse_args()
    input_path = Path(args.input_path).expanduser().resolve()
    output_path = Path(args.output_path).expanduser().resolve() if args.output_path else input_path
    fields = [f.strip() for f in str(args.fields).split(",") if f.strip()]

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")
    if not fields:
        raise ValueError("No fields provided. Example: --fields name,DESCRIPTION")

    with input_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    products = load_products(payload)
    changed_rows = 0
    changed_fields = 0
    samples: list[tuple[str, str, str]] = []

    for row in products:
        row_changed = False
        for field in fields:
            if field not in row:
                continue
            next_value, changed = clean_vat_text(row.get(field))
            if not changed:
                continue
            before = str(row.get(field, ""))
            row[field] = next_value
            changed_fields += 1
            row_changed = True
            if len(samples) < 8:
                samples.append((field, before, str(next_value)))
        if row_changed:
            changed_rows += 1

    print(f"Input: {input_path}")
    print(f"Output: {output_path}")
    print(f"Fields: {', '.join(fields)}")
    print(f"Rows changed: {changed_rows}")
    print(f"Field updates: {changed_fields}")
    if samples:
        print("\nSample updates:")
        for idx, (field, before, after) in enumerate(samples, start=1):
            print(f"{idx}. {field}:")
            print(f"   - before: {before}")
            print(f"   - after : {after}")

    if args.dry_run or changed_fields == 0:
        print("\nDry run: no file written." if args.dry_run else "\nNo changes needed.")
        return 0

    if output_path == input_path and not args.no_backup:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = input_path.with_suffix(input_path.suffix + f".bak.{stamp}")
        shutil.copy2(input_path, backup_path)
        print(f"Backup: {backup_path}")

    write_json(output_path, payload)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
