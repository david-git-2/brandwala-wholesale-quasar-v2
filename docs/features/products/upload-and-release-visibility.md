# Catalog refresh log (scrape / upload) & app release versions

## As-built

| | |
| :--- | :--- |
| Status | **Backend in** — tables, RPCs, Python log writes, deploy version writes. **UI later** |
| Spec parent | [spec.md](spec.md) |
| Excel upload | `pnpm run pc:uploader`, `pnpm run wts:uploader` |
| Pipelines | `python/Makefile` — `pc`, `wts`, `wts-excel`, `elf`, `koba-retail`, `koba-wholesale`, `*-scrape`, `*-sync` |
| Deploy | `pnpm run deploy:backend`, `pnpm run deploy:frontend` |
| Rollback (unchanged) | `product_sync_snapshots` — not for staff UI |

## Goal

Staff in the **app** see recent catalog **scrapes** and **uploads**, plus live **backend / frontend** version.

| Kind | Show |
| :--- | :--- |
| Scrape | Website URL, scrape date/time, products updated, runtime (seconds) |
| Upload | File name, upload date/time, products updated, runtime (seconds) |
| Release | `backend_version`, `frontend_version` (+ when each last changed) |

`parent_tenant_id` on every refresh row = **the same value the pipeline uses for product sync** (`--parent-tenant-id` on `sync_*_products_to_supabase.py`), read from the script args/env — not a UI guess.

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` — catalog admins |
| In | `catalog_refresh_log`, `app_release_versions`, Python + deploy writers, read RPC, simple UI |
| Out | Per-SKU audit, failed-run error text, CI dashboards |

## Table 1 — `catalog_refresh_log`

One row per **scrape** or **upload** run (when that step finishes).

| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | `bigserial` | PK |
| `parent_tenant_id` | `bigint` | From script: `args.parent_tenant_id` / `--parent-tenant-id` / `PY_PRODUCTS_PARENT_TENANT_ID` — **must match** the sync that owns that vendor scope |
| `source` | `text` | Stable key — see [Source registry](#source-registry) |
| `event_kind` | `text` | `'scrape'` \| `'upload'` |
| `source_url` | `text` | **Scrape:** catalog site base URL (see registry). **Upload:** null |
| `file_name` | `text` | **Upload:** original Excel name (Streamlit `uploaded.name`). **Scrape:** null |
| `ran_at` | `timestamptz` | End time of the step (default `now()`) |
| `products_updated` | `integer` | Meaning below |
| `duration_seconds` | `integer` | Wall-clock seconds for that step; null if not measured |

Check: `(event_kind = 'scrape' and source_url is not null and file_name is null)` OR `(event_kind = 'upload' and file_name is not null)`.

Index: `(parent_tenant_id, source, event_kind, ran_at desc)`.

### `products_updated` meaning

| `event_kind` | Set from |
| :--- | :--- |
| `scrape` | Product count in output JSON after export (`meta.count` or `len(products)`) — rows harvested into the catalog file |
| `upload` | DB sync for that run: **successful inserts + successful updates** (from `sync_pc_products_to_supabase.py` / `sync_wts_products_to_supabase.py` counters at end of write phase) |

Scrape-only Makefile targets (`wts-scrape`, `elf-scrape`, …) log **scrape** only. Full targets (`wts`, `pc`, …) log **upload** when Excel was used, or log **scrape** then **sync counts on a second upload/sync row** only when sync runs in the same invocation — prefer **one upload row** after full `make pc` / `make wts-excel` with sync totals; **one scrape row** after `*-scrape` with JSON count.

### `parent_tenant_id` by pipeline

Use the **sync** flag from `python/Makefile` (same as product inserts):

| `source` | `--parent-tenant-id` (typical) |
| :--- | :--- |
| `pc`, `wts`, `wts_excel`, `elf` | `15` (`PC_SYNC_FLAGS` / `WTS_SYNC_FLAGS` / `elf` target) |
| `koba_retail`, `koba_wholesale` | `10` (`koba-*-sync`) |

Scrape scripts that do not parse `--parent-tenant-id` today should accept the same flag (or `PY_PRODUCTS_PARENT_TENANT_ID`) **only for logging**, using the value from the paired sync row in the Makefile.

### Source registry

Register new scrapers/uploaders with a `source` key and `source_url` (scrape).

| `source` | `event_kind` | `source_url` (scrape) | Export script |
| :--- | :--- | :--- | :--- |
| `pc` | `upload` | — | Excel → `export_pc_data.py` (no public scrape URL) |
| `wts` | `scrape` | `https://wholesaletradingsupplies.com` | `export_wts_data.py` |
| `wts_excel` | `upload` | — | `export_wts_excel.py` + sync |
| `pc_pricecheck` | `scrape` | `https://shop.pricecheck.uk.com` | `export_pricecheck_scraper.py` |
| `elf` | `scrape` | `https://elfinternationalltd.com` | `export_elf_data.py` |
| `koba_retail` | `scrape` | `https://www.kobareseller.com` | `export_koba_retail_data.py` |
| `koba_wholesale` | `scrape` | `https://www.kobainternational.com` | `export_koba_wholesale_data.py` |

Add a row here when a new `export_*` scraper or uploader is added.

## Table 2 — `app_release_versions`

Unchanged: single row `id = 1`.

| Column | Type |
| :--- | :--- |
| `backend_version` | `text` |
| `frontend_version` | `text` |
| `backend_updated_at` | `timestamptz` |
| `frontend_updated_at` | `timestamptz` |

Version string = root `package.json` semver; patch bump on each successful backend or frontend deploy (`scripts/bump-app-release-version.sh`).

## Who writes

| Event | Where | Row |
| :--- | :--- | :--- |
| Scrape finished | End of each `export_*` script (or shared helper) | `event_kind = scrape`, `source_url`, `products_updated`, `duration_seconds`, `parent_tenant_id` from args/env |
| Excel upload + sync | Streamlit after save + sync, or end of `sync_*` after `make pc` / `wts-excel` | `event_kind = upload`, `file_name`, sync insert+update totals, `duration_seconds` |
| Backend / frontend deploy | `deploy-backend.sh` / `deploy-frontend.sh` | Upsert `app_release_versions` |

Writer: `service_role` (same as product sync).

## Who reads

| RPC (examples) | Returns |
| :--- | :--- |
| `list_catalog_refresh_log(p_parent_tenant_id, p_limit)` | Recent scrape + upload rows for that parent |
| `get_app_release_versions()` | Backend + frontend version strings and dates |

`SECURITY DEFINER`; grant to catalog admins (same as products area).

## Not the same as

| Thing | Why |
| :--- | :--- |
| `product_sync_snapshots` | Rollback rows; expires in 7 days |
| JSON `meta.generatedAt` | File on disk / CDN; not the staff activity log |
| `products.updated_at` | Per product, not per scrape/upload run |

## Implementation checklist

- [x] Migration: `catalog_refresh_log` + `app_release_versions` seed
- [x] Shared Python helper: `python/scripts/uk/catalog_refresh_lib.py`
- [x] `parent_tenant_id` from sync args / scrape `--parent-tenant-id` / Makefile
- [x] `duration_seconds` + `products_updated` on scrape and sync
- [x] Streamlit sets `CATALOG_UPLOAD_FILE_NAME` + `CATALOG_REFRESH_SOURCE`
- [x] `scripts/record-app-release.sh` from `deploy-backend.sh` / `deploy-frontend.sh`
- [x] Profile menu shows backend/frontend versions (`UserProfileMenu.vue`)
- [ ] Products UI: scrape/upload history list
- [ ] `pnpm run backend:local` then types (apply migration locally)
