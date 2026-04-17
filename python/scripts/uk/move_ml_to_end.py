#!/usr/bin/env python3
"""Move ML quantity tokens to the end of product name fields in JSON product data."""

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

ML_TOKEN_RE = re.compile(
    r"\b(\d+(?:\.\d+)?)\s*ml(?:\s*/\s*(\d+(?:\.\d+)?)\s*oz)?\b",
    re.IGNORECASE,
)
MULTISPACE_RE = re.compile(r"\s{2,}")
SPACE_BEFORE_PUNCT_RE = re.compile(r"\s+([,;:])")
SPACE_AFTER_OPEN_PAREN_RE = re.compile(r"(\()\s+")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Move ML quantity tokens to the end of product names in JSON data.",
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
        help="Comma-separated string fields to normalize (default: name)",
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


def normalize_ml_token(match_text: str) -> str:
    found = ML_TOKEN_RE.search(match_text)
    if not found:
        return match_text.strip()
    quantity_ml = found.group(1)
    quantity_oz = found.group(2)
    if quantity_oz:
        return f"{quantity_ml}ML/{quantity_oz}OZ"
    return f"{quantity_ml}ML"


def move_ml_tokens_to_end(value: Any) -> tuple[Any, bool]:
    if not isinstance(value, str):
        return value, False

    matches = list(ML_TOKEN_RE.finditer(value))
    if not matches:
        return value, False

    ml_tokens: list[str] = []
    parts: list[str] = []
    cursor = 0

    for match in matches:
        parts.append(value[cursor : match.start()])
        ml_tokens.append(normalize_ml_token(match.group(0)))
        cursor = match.end()
    parts.append(value[cursor:])

    core = "".join(parts)
    core = SPACE_BEFORE_PUNCT_RE.sub(r"\1", core)
    core = SPACE_AFTER_OPEN_PAREN_RE.sub(r"\1", core)
    core = MULTISPACE_RE.sub(" ", core).strip(" -_/")
    ml_suffix = " ".join(token for token in ml_tokens if token)

    if core and ml_suffix:
        updated = f"{core} {ml_suffix}"
    else:
        updated = core or ml_suffix

    updated = MULTISPACE_RE.sub(" ", updated).strip()

    # Safety: never collapse a non-empty value to empty.
    if value.strip() and not updated:
        return value, False

    return updated, updated != value


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
            next_value, changed = move_ml_tokens_to_end(row.get(field))
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
