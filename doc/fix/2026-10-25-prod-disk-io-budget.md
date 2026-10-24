# Prod disk IO budget (2026-10-25)

One-off ops note. Not product truth. Related bundle work: [2026-10-18-perf-next-steps.md](2026-10-18-perf-next-steps.md).

## Symptom

Supabase: **“Your project is about to deplete its Disk IO Budget.”** After the budget hits zero, disk is capped at ~**5 MB/s** until usage stays at baseline.

This is **not** “disk full.” Prod used ~**0.11 GB** of **8 GB**.

## What we saw (last 3h, 25 Oct 2026 ~00:32–03:32)

| Signal | Reading | Meaning |
| :--- | :--- | :--- |
| Memory commitment | **SEVERE** ~1.34 / 1.48 GB | Box is out of RAM |
| Swap | Used | RAM spilled to disk → burns IO budget |
| CPU | ~3% but **IOWait** spikes | Waiting on disk, not busy CPU |
| Disk IOPS / throughput | Very low at screenshot time | Quiet hour **or** already throttled |
| Table size | `products` ~20 MB, snapshots ~16 MB | Data size is not the problem |

`pg_stat_statements` (cache hit ~100% on heavy rows):

| Rank | What | Calls | Mean | Total |
| :--- | :--- | ---: | ---: | ---: |
| 1 | `realtime.list_changes` (WAL) | 1.18M | 6.9 ms | **8.1M ms** |
| 2 | `pg_timezone_names` | 2.8k | **906 ms** | 2.5M ms |
| 3 | Studio schema (`pg_available_extensions`, `with tables as`) | ~1–3k | 150–750 ms | large |
| App | `get_my_notification_unread_count` | 3.6k | 169 ms | 609k ms |
| App | `list_products_paginated` (search filters) | 1.8k | 236 ms | 433k ms |
| App | `get_shipment_overview_details` | 1.2k | 280 ms | 322k ms |

`shared_blks_read` on those app queries was tiny. Stress is **CPU + RAM + WAL + many round trips**, not sequential scans of huge tables.

## Cause (ranked)

| # | Cause | Source | Offload to Vue? |
| :--- | :--- | :--- | :--- |
| 1 | Tiny compute + swap | Supabase plan | **No** |
| 2 | Realtime WAL (`notification_recipients` on publication; bell on app + shop) | `notifications/` | **No** — only stop subscribe |
| 3 | Supabase **Dashboard / Studio** left open on prod | supabase.com, not in-app dashboard | **No** — close tabs |
| 4 | Product search `~*` regex per token on `name\|\|brand` | `list_products_paginated` | **No** — dumping catalog into the browser is worse |
| 5 | Overview RPC packs **all items + boxes + costs**; also **writes** cost rows on read (`ensure_global_shipment_cost_entries_from_header`) | `get_shipment_overview_details` | Cache longer; **don’t** recompute costing in Vue |
| 6 | Line-item **save on each cell blur** → `update_global_shipment_item` returns **all lines** + restamp | `ShipmentLineItemsV2Page` | Draft in memory, **one save**. Costing stays on server |
| 7 | `get_app_bootstrap_context` **refetch on window focus** | `useAppBootstrapQuery` | Turn focus refetch off. Keep the RPC. |
| 8 | Python PC/WTS sync + `product_sync_snapshots` | `python/scripts/uk/` | Run off-peak, not on this box |

**Studio vs in-app:** `pg_timezone_names` / `with tables as` = **supabase.com**. In-app pages look like `WITH pgrst_source` + `public.*` RPCs.

**Autosave (shop settings, dropship desk):** already debounced. Not the top offender. **Shipment cell blur** is the costly “autosave.”

## Do not move to the frontend

Search, RLS, landed-cost stamp, and `COUNT(*)` over stock **must stay in Postgres**. Client-side catalog / costing **increases tab RAM** and still hits the API (or goes stale).

Safe on the frontend (cheap): debounce, optimistic row, Vue Query cache, no refetch-on-focus. That **cuts** DB work; it does not add heavy UI compute.

## Already done (code)

| Change | Where |
| :--- | :--- |
| In-app notifications **off** (no bell, no Realtime, RPCs stubbed) | `web/src/modules/notifications/notificationsFeature.ts` (`NOTIFICATIONS_ENABLED = false`) |
| App admin dashboard **one RPC** + manual refresh + local cache | `get_app_dashboard_bundle`, `dashboardBundleStore`, migration `20271025120000_get_app_dashboard_bundle.sql` |

Restore: set that flag to `true` and redeploy **web**. Needs bigger compute or a lighter Realtime plan first.

## Staying on free / smallest tier (no compute upgrade)

| Mitigation | Notes |
| :--- | :--- |
| Notifications off in app | `NOTIFICATIONS_ENABLED = false` — cuts Realtime WAL |
| Never leave Studio open on prod | Cuts `pg_timezone_names` + schema introspection |
| Product name search trgm + `ILIKE` | Migration `20271025103000_products_name_search_trgm.sql` — lower CPU per search |
| Shipment row save (not per cell) | Backlog — fewer writes |
| Bootstrap: no refetch on focus | Backlog |
| PC/WTS sync off-peak only | Avoid write spikes on shared instance |

Free tier still has **hard RAM limits**; mitigations reduce load but cannot remove swap risk entirely.

## Solutions (do in this order)

| # | Action | Who | Effect |
| :--- | :--- | :--- | :--- |
| 1 | **Upgrade compute** (more RAM) — *skipped if staying on free tier* | Supabase | Stops swap; main fix when affordable |
| 2 | Close **Studio** on prod; explore on local | Humans | Cuts catalog queries |
| 3 | Keep notifications off until compute is bigger; later: subscribe only on inbox, or poll badge every 60–120s — **not** 2s poll | App | Cuts WAL |
| 4 | Shipment grid: debounce / save **row**, RPC returns **one row**, restamp not per cell | App + SQL | Fewer writes |
| 5 | Product search: `ILIKE` / `pg_trgm`, not `~*` on concat | SQL | **Done** — `20271025103000_products_name_search_trgm.sql` |
| 6 | Overview: don’t ensure cost rows on **read**; longer `staleTime`; don’t refetch after every cell | SQL + app | Fewer writes/reads |
| 7 | Bootstrap: `refetchOnWindowFocus: false` | App | Fewer grants fetches |
| 8 | Product sync off-peak / not against this instance | Ops | Write spikes |

## Re-check after deploy

SQL Editor (read-only). Compare to the tables above after a **normal work day** with Studio closed:

```sql
SELECT calls, round(mean_exec_time::numeric, 2) AS mean_ms,
       round(total_exec_time::numeric, 2) AS total_ms,
       left(query, 200) AS query_preview
FROM pg_stat_statements
WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY total_exec_time DESC
LIMIT 15;
```

`realtime.list_changes` should drop after the web deploy (old tabs still subscribed until refresh). Studio rows drop when those tabs close.
