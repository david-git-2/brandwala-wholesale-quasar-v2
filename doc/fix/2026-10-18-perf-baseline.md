# Perf baseline (Phase 1)

One-off measurement for the optimization program. Not product truth. Date: 2026-10-18.

## How to reproduce bundle stats

```bash
cd web && npm run build:analyze
```

`PERF_ANALYZE=1` enables Quasar `build.analyze` ([quasar.config.ts](../../web/quasar.config.ts)).

Build machine: local prod build after fixing missing `LinkCustomerProfileDialog.vue` (build was failing without it).

## Top 10 JS assets (minified, `dist/spa/assets`)

| Rank | Size | File | Notes |
| :--- | ---: | :--- | :--- |
| 1 | 1425 KiB | `elk-276RUBZZ-*.js` | Mermaid / diagram (lazy with dev doc) |
| 2 | 908 KiB | `exceljs.min-*.js` | Excel export (dynamic import) |
| 3 | 806 KiB | `DevDocumentPage-*.js` | Dev doc + mermaid |
| 4 | 647 KiB | `chunk-FOHPRMQF-*.js` | Shared vendor chunk |
| 5 | 425 KiB | `cytoscape.esm-*.js` | Mermaid dependency |
| 6 | 253 KiB | `katex-*.js` | Mermaid / math |
| 7 | 234 KiB | `chunk-O7XYJQB3-*.js` | Shared chunk |
| 8 | 207 KiB | `usecaseDiagram-*.js` | Mermaid diagram type |
| 9 | 205 KiB | `supabase-*.js` | Supabase client (entry preload) |
| 10 | 200 KiB | `index-*.js` | App entry |

Total JS (build summary): **~12.2 MB** raw across 630 files. Largest single warning: chunk > 500 KiB (Vite).

## CSS (`cssCodeSplit: false`)

| Asset | Raw | Gzipped (build report) |
| :--- | ---: | ---: |
| `assets/style-*.css` | **857 KiB** | **137 KiB** |

One bundle ships all route styles on first load.

## Firebase / chart.js in main chunk?

| Library | In `index-*.js` entry? | Where |
| :--- | :---: | :--- |
| **firebase** | No | `NotificationPreferencesPage-*.js` only (~47 KiB) |
| **chart.js** | No | `dist-*.js`, `DashboardDonut-*.js`, `DesignSystemPage-*.js` (lazy routes) |

## Static JSON (was `public/uk`, now `python/data/uk/out`)

Moved out of `web/public` on 2026-10-18. The web app never loaded them and deploy already removed them. Sizes at time of baseline:

| File | ~Size |
| :--- | ---: |
| `uk/pc_scraped_data.json` | 3.5 MB |
| `uk/pc_data.json` | 3.1 MB |
| `uk/koba_retail_data.json` | 2.5 MB |
| `uk/wts_data.json` | 438 KiB |

## Lighthouse (dashboard, shop orders, procurement demand)

**Not captured in CI.** Local Lighthouse run did not complete (Chrome spawn aborted in agent env).

**Manual rerun** (logged-in scores matter):

1. `cd web && npm run build && npx serve dist/spa -l 8787 -s`
2. Sign in as app user in Chrome.
3. Run Performance on:
   - `/{tenantSlug}/app/dashboard`
   - `/{tenantSlug}/app/shop/orders`
   - `/{tenantSlug}/app/procurement/demand`
4. Paste scores below.

| Page | Performance | LCP | TBT | CLS |
| :--- | ---: | ---: | ---: | ---: |
| Admin dashboard | _pending_ | | | |
| Shop orders | _pending_ | | | |
| Procurement demand | _pending_ | | | |

Unauthenticated cold load only measures login + shell, not real ERP pages.

## Supabase — 10 slowest queries

**Not captured** (requires Supabase Dashboard → Reports → Query performance, or Log Explorer on linked project).

Paste when available:

| # | Query / RPC | Mean time | Calls |
| :--- | :--- | ---: | ---: |
| 1 | _pending_ | | |
| … | | | |

## Follow-ups for Phase 2+

- Shrink first paint: CSS split, `manualChunks`, Phosphor font weight (SVG font ~2.9 MB in assets).
- Keep firebase/chart lazy; entry already clean.
- Lighthouse + Supabase tables above before Phase 4 DB work.

## Phase 2 result (2026-10-18)

| Item | Before | After |
| :--- | :--- | :--- |
| CSS on first load | 857 KiB (1 file) | 281 KiB (vendor-quasar 191 + index 90); rest per route |
| CSS files | 1 | 199 |
| Vendor chunks | none | vendor-vue, vendor-quasar, vendor-supabase, vendor-firebase (lazy) |
| material-icons font | shipped | removed (toasts use Phosphor) |
| chart.js | lazy route chunk | unchanged (already lazy; no vendor-chart group, it pulled chart into first load) |

Skipped: boot reorder (needs login-flow testing), async chart wrappers (no gain, chart already off the entry).

## Supabase slow queries (pasted 2026-10-18)

| Query | Source | Verdict |
| :--- | :--- | :--- |
| `pgbouncer.get_auth` 26k calls | Supabase pooler | Ignore |
| `schema_migrations` select, 1339 calls, 43 ms | CLI (`backend:*`) | Dev only |
| `storage.objects` inserts, 41k | Storage uploads | Not on request path |
| `products order by id desc` (`_base_query`) 244 ms | Supabase Studio | Ignore |
| `product_sync_snapshots` COPY/DELETE 0.8-3.6 s | ETL / pg_dump | Indexes exist (`expires_at`, scope) |
| barcode count on `products` 859 ms, 3 calls | ETL | Indexes exist; low volume |
| `inventory_accounting_entries` explain | Studio | Ignore |

Result: no slow app (user) query in the top 10. Phase 4 needs no new indexes.
