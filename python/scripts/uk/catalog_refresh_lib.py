"""Log scrape/upload runs to public.catalog_refresh_log. Failures never abort the pipeline."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from product_sync_lib import (
    SupabaseRestClient,
    env_int,
    to_text,
)

SCRAPE_URLS: dict[str, str] = {
    "wts": "https://wholesaletradingsupplies.com",
    "pc_pricecheck": "https://shop.pricecheck.uk.com",
    "elf": "https://elfinternationalltd.com",
    "koba_retail": "https://www.kobareseller.com",
    "koba_wholesale": "https://www.kobainternational.com",
}


def add_parent_tenant_argument(parser: Any, default: int) -> None:
    parser.add_argument(
        "--parent-tenant-id",
        dest="parent_tenant_id",
        type=int,
        default=env_int("PY_PRODUCTS_PARENT_TENANT_ID", default),
        help=f"Warehouse parent tenant id used on product sync (default: {default}).",
    )


def resolve_parent_tenant_id(raw: Any, default: int) -> int:
    if raw is None:
        return env_int("PY_PRODUCTS_PARENT_TENANT_ID", default)
    try:
        value = int(raw)
        return value if value > 0 else default
    except (TypeError, ValueError):
        return default


def resolve_upload_file_name(explicit: str | None, input_path: Path | None = None) -> str:
    name = to_text(explicit or os.getenv("CATALOG_UPLOAD_FILE_NAME"))
    if name:
        return Path(name).name
    if input_path is not None:
        return input_path.name
    return "unknown"


def resolve_catalog_source(explicit: str | None, fallback: str) -> str:
    source = to_text(explicit or os.getenv("CATALOG_REFRESH_SOURCE") or fallback).lower()
    return source.replace("-", "_")


def _client() -> SupabaseRestClient | None:
    supabase_url = to_text(os.getenv("SUPABASE_URL") or os.getenv("VITE_SUPABASE_URL"))
    supabase_key = to_text(
        os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    )
    if not supabase_url or not supabase_key:
        print("catalog_refresh_log skipped: missing SUPABASE_URL or service role key.", flush=True)
        return None
    return SupabaseRestClient(supabase_url, supabase_key)


def log_catalog_refresh(
    *,
    parent_tenant_id: int,
    source: str,
    event_kind: str,
    products_updated: int | None,
    duration_seconds: int | None,
    source_url: str | None = None,
    file_name: str | None = None,
) -> None:
    try:
        client = _client()
        if client is None:
            return
        row: dict[str, Any] = {
            "parent_tenant_id": int(parent_tenant_id),
            "source": to_text(source).lower(),
            "event_kind": event_kind,
            "products_updated": products_updated,
            "duration_seconds": duration_seconds,
        }
        if event_kind == "scrape":
            row["source_url"] = to_text(source_url) or SCRAPE_URLS.get(row["source"])
            row["file_name"] = None
            if not row["source_url"]:
                print(
                    f"catalog_refresh_log skipped: no source_url for scrape source={row['source']}.",
                    flush=True,
                )
                return
        else:
            row["file_name"] = to_text(file_name) or None
            row["source_url"] = None
            if not row["file_name"]:
                print("catalog_refresh_log skipped: upload missing file_name.", flush=True)
                return
        client.insert_rows("catalog_refresh_log", [row])
        print(
            "catalog_refresh_log: "
            f"{event_kind} source={row['source']} parent={parent_tenant_id} "
            f"products_updated={products_updated} duration_seconds={duration_seconds}",
            flush=True,
        )
    except Exception as exc:
        print(f"catalog_refresh_log failed (pipeline continues): {exc}", flush=True)


def log_scrape(
    *,
    source: str,
    parent_tenant_id: int,
    products_updated: int,
    duration_seconds: int | None,
    source_url: str | None = None,
) -> None:
    log_catalog_refresh(
        parent_tenant_id=parent_tenant_id,
        source=source,
        event_kind="scrape",
        products_updated=products_updated,
        duration_seconds=duration_seconds,
        source_url=source_url,
    )


def log_upload(
    *,
    source: str,
    parent_tenant_id: int,
    file_name: str,
    products_updated: int,
    duration_seconds: int | None,
) -> None:
    log_catalog_refresh(
        parent_tenant_id=parent_tenant_id,
        source=source,
        event_kind="upload",
        products_updated=products_updated,
        duration_seconds=duration_seconds,
        file_name=file_name,
    )
