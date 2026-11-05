# Tenant id cutover (`parent_tenant_id` → `tenant_id`)

## Prod SQL sequence

Copy **only** rows with `parent_tenant_id = 15`. Do not copy other companies. Linked prod. Run **in this order**. Stop if a step looks wrong.

```bash
pnpm run env:prod

# 0 — preflight (read-only): RUN_COPY vs SKIP_COPY
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_preflight.sql

# 1 — confirm 15 is parent of 10 and 11 (also in preflight)
pnpm exec supabase db query --linked "
SELECT id, name, parent_id, slug
FROM public.tenants
WHERE id IN (10, 11, 15) OR parent_id = 15
ORDER BY id;
"

# 2 — preview (no writes) — skip 2–4 if preflight said SKIP_COPY
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent.sql

# 3 — apply (writes tenant_id = 15)
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent_apply.sql

# 4 — verify
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent_verify.sql
```

Not a migration. Do not run `backend:prod` **for the copy** (run `backend:prod` **after** copy or documented skip — see [11b](#11b--push-backend)).

**Skip copy when:** preflight `decision` = `SKIP_COPY` (prod already dropped `shops.parent_tenant_id`, e.g. phase **4** migrations applied before copy). Note the skip in your release log, then go to **11b**. **Do not** run apply if dual column is gone — the script will error.

**Run copy when:** preflight = `RUN_COPY` and preview counts look sane (no unexpected slug clashes; recipient phone collision list is acceptable).

## Agent phases (one phase per run)

Do **not** mix phases. After SQL: `pnpm run backend:local` (not reset) then `backend:types:local`. Grep one symbol in `supabase/schemas/`; do not full-read `public.sql` or `database.types.ts`. Never rename `tenants.parent_id`. Never write child **ops** companies onto warehouse rows.

**Code (phases 1–10): never hardcode a tenant id.** No literal `15`, `10`, `11`, or any other company id in SQL functions, RLS, TS, or Python. Books owner = `resolve_books_tenant_id(selected_tenant_id)` (or the same helper already in the module). Selected tenant = current login / RPC `p_tenant_id` / shop or cart company. Historical `parent_tenant_id` in data-copy scripts is the **old column name on prod until migrations run** — not a number to paste in app code. `10` / `11` / `15` below are **as-built examples** for this DB’s data-copy scripts only.

| Phase | Status | Ship | Depends |
| :--- | :--- | :--- | :--- |
| **0** | local done (**prod left**) | Data copy **only** where dual rows still have old column (see [Prod readiness](#prod-readiness)) | — |
| **1** | done | Shop-order **create** writes warehouse `tenant_id` (derived) | 0 |
| **2** | done | Shop-order **list/get** use `o.tenant_id` | 1 |
| **3** | done | Shops list RPCs + web use `tenant_id` | 0 |
| **4** | done | Dual-table readers; drop `parent_tenant_id` on dual tables | 1–3 |
| **5** | done | Bills/pays RPC arg `p_parent_tenant_id` → `p_tenant_id` (column name unchanged) | 0 |
| **6** | done | Stock/procurement RPC args same rename | 0 |
| **7** | done | Remaining RPC args (products, notify, purge, dashboard, shop list unused arg) | 5–6 |
| **8** | done locally | Rename column `parent_tenant_id` → `tenant_id` (8a–8d) | 5–7 |
| **9** | done locally | Python / Makefile flags; leftover SQL scripts | 8 |
| **10** | done locally | Books RPC renames; schema/doc cleanup | 4 + 8 + 9 |
| **11** | **left** | Prod data copy → `backend:prod` → deploy → smoke; stragglers + RPC/OUT cleanup | 0 + 8–10 |

Phase detail is at the bottom: [Agent phase detail](#agent-phase-detail).

## Prod readiness

**Verdict: not ready for prod cutover yet.** Local repo + local DB match phases **1–10** (hand-written `web/src/modules`, `supabase/schemas/`, `python/` have no `parent_tenant_id`). Production still needs the human sequence below and phase **11** stragglers.

### Blockers (must fix before calling cutover “live on prod”)

| # | Issue | Why it matters | Address in |
| :---: | :--- | :--- | :--- |
| 1 | **Phase 0 not run on prod** | Child ops rows (shops, orders, brands, …) may still use tenant **10/11** while app/RPCs expect warehouse **15** on `tenant_id`. | Phase **11a** — [Prod SQL sequence](#prod-sql-sequence) steps 1–4 **before** `backend:prod` if prod still has dual `parent_tenant_id` on those tables |
| 2 | **Migrations 8a–10 not on prod** | Prod schema/RPCs still use old column names and `resolve_parent_tenant_id` until pushed. | Phase **11b** — `pnpm run backend:prod` then `pnpm run backend:types` |
| 3 | **Web not deployed** | App calls `resolve_books_tenant_id`; prod API must expose it after migration 10. | Phase **11c** — `pnpm run frontend:prod` after **11b** |
| 4 | **`delivery_paper` / `stock_physical_counts` still `parent_tenant_id` on DB** | Not renamed in declarative schema; local `database.types.ts` still shows `delivery_paper.parent_tenant_id`, ledger OUT columns, etc. Delivery-paper RLS in old migrations references `delivery_paper.parent_tenant_id`. | Phase **11d** — migration + schema sync |
| 5 | **Phase 10 partial RPC redeploy** | Many functions still call deprecated wrapper names in `prosrc`; list RPCs (`search_stock_network`, cashbook ledger, …) still **RETURNS** `parent_tenant_id` OUT columns — `CREATE OR REPLACE` with new OUT shape fails (42P13) unless dropped first. | Phase **11e** — targeted DROP/CREATE or leave OUT names until a dedicated pass |
| 6 | **Deprecated SQL wrappers** | `resolve_parent_tenant_id`, `user_can_manage_parent_tenant`, … wrappers exist after migration 10 (intentional short-term). | Phase **11e** — drop after all callers redeployed |
| 7 | **Prod catalog sync not re-run** | Product rows on prod still keyed on old column until sync after **11b**. | Phase **11f** — Makefile / `python:sync:*` with `--tenant-id` (no `--parent-tenant-id`) |

### Safe prod order (do not reorder)

1. Confirm prod tenant tree (15 root; 10/11 children) — sequence step **1**.
2. If prod still has `parent_tenant_id` on dual tables (`shops`, `shop_orders`, …): run copy **preview → apply → verify** (steps **2–4**). If prod already ran phase **4** migrations and dropped that column, **skip copy** for those tables and document what was done manually.
3. `pnpm run backend:prod` — applies pending migrations including `2026110521*` (8a–8d) and `20261106120000_tenant_id_phase10_cleanup.sql`.
4. `pnpm run backend:types` — refresh types from **linked** prod (CI/deploy uses this).
5. `pnpm run frontend:prod` — SPA aligned with new RPC names.
6. Phase **11** smoke (shop order, bills list, stock search, delivery paper, catalog sync dry-run against prod).
7. Optional: Python full sync on prod env (human; not in CI).

### Already OK locally

- Declarative `supabase/schemas/` — no `parent_tenant_id` (except cutover/history docs).
- Hand-written web modules — use `tenant_id` / `resolve_books_tenant_id`.
- Python pipelines — `--tenant-id` / `--inserted-by-tenant-id`; ops SQL `document_numbering_*` + backfill scripts updated in phase 9.

### Domain coverage (must all land in a phase)

| Domain | Tables / notes | Phase |
| :--- | :--- | :--- |
| Shop orders + dropship | `shop_orders` create/list; desk | **1–2**, drop col **4** |
| Shops + permissions + catalog refresh UI | `shops`; `shopPermissionsRepository`; `catalogRefreshRepository` | **3**, **7 done**, drop **4** / col **8a** |
| Products + brands/categories | `products` (parent-only); dual `product_brands`, `product_categories` | dual **4**; products **8a done** + **9** |
| Pre-order / PBC | `preorder_demand` dual; PBC header creates **profile** via `parent_tenant_id` | demand **4**; profile write **5/7** + col **8c** |
| Procurement / stock / cargo / batch / locations / delivery paper | `global_stocks`, shipments, outcomes, locations, `cargo_companies`, `batch_code_lists`, `delivery_paper`, stock types | args **6 done**; cols **8b done** |
| Money: bills, pays, cashbook, brands, FX | `bills`, `bill_lines`, `bill_settlements`, cashbook dual + points, `invoice_brands`, `books_exchange_rates`; `issued_by_tenant_id` stays | args **5 done**; dual cashbook **4**; cols **8c done** |
| Customers / groups / recipients / profiles | `customer_groups`, `recipient_profiles` dual; `profiles` parent-only | dual **4**; `upsert_profile_for_party` **7 done**; cols **8c done** |
| Vendors | `vendors` | **8c done** |
| After-sales | pages/dialogs/stubs write `tenant_id` on bill-shaped payloads | **8c done** |
| Notifications | `notifications`; inbox RPCs | args **7 done**; col **8d done** |
| Dashboard | `get_app_dashboard_bundle` | **7 done** |
| Tenant purge / child refs | purge RPCs | **7 done** |
| Python PC/WTS/ELF/Koba pipelines | REST `parent_tenant_id` | **9** (after **8a**) |
| RLS + ~318 SQL function **bodies** (not only 47 args) | grep `parent_tenant_id` in `public.sql` | **4** (dual) then **8** (parent-only) |
| Reporting / thrift / koba **web** / investor / settings / docs UI | no `parent_tenant_id` in those web modules today | **out** unless grep finds a new hit |
| Company tree | `tenants.parent_id` | **never change** |

## As-built (local DB, 2026-11-05)

| | |
| :--- | :--- |
| Warehouse company | `tenants.id = 15` (`bw`, name BW, `parent_id` null) |
| Child companies | `10` Wholesale, `11` Dropshipping (`parent_id = 15`) |
| Goal | Books / warehouse rows use **`tenant_id = 15`**. Drop `parent_tenant_id` later. |
| SQL inventory | Live `information_schema` + `pg_proc` on local Supabase |
| Scripts | [preflight](../../scripts/sql/tenant_id_copy_preflight.sql) · [preview](../../scripts/sql/tenant_id_copy_parent.sql) · [apply](../../scripts/sql/tenant_id_copy_parent_apply.sql) · [verify](../../scripts/sql/tenant_id_copy_parent_verify.sql) |

Do **not** delete child tenants. They stay as `tenants` rows. Child **10 / 11** are login/ops companies. Warehouse books become **15** on business tables.

## Scope

| | |
| :--- | :--- |
| In | Public tables with `parent_tenant_id`; RPCs with `p_parent_tenant_id`; Python/Makefile flags `--parent-tenant-id` |
| Out | `tenants.parent_id` (company tree). Do not rename that. |
| This pass | Data copy (phase 0) is the SQL scripts. Code cutover is [Agent phases](#agent-phases-one-phase-per-run) 1–10. |

## 1 — Tables

### A. Both columns — copy `parent_tenant_id` into `tenant_id`

Local counts where `parent_tenant_id = 15` and `tenant_id` is not 15:

| Table | Rows parent=15 | Already tenant=15 | Need copy | Current `tenant_id` |
| :--- | ---: | ---: | ---: | :--- |
| `shop_orders` | 16 | 0 | **16** | 10 (13), 11 (3) |
| `shops` | 6 | 0 | **6** | 10 (5), 11 (1) |
| `recipient_profiles` | 13 | 0 | **13** | 10 (1), 11 (12) |
| `product_brands` | 2080 | 0 | **2080** | 10 / 11 / null |
| `product_categories` | 322 | 0 | **322** | 10 / 11 / null |
| `preorder_demand` | 152 | 150 | **2** | leftover 10 |
| `customer_groups` | 22 | 22 | 0 | already 15 |
| `cashbook_accounts` | 10 | 10 | 0 | already 15 |
| `cashbook_entries` | 20 | 20 | 0 | already 15 |
| `global_invoice_items` | 49 | 49 | 0 | already 15 |
| `global_return_items` | 0 | 0 | 0 | — |
| `invoice_write_offs` | 0 | 0 | 0 | — |

`shops` unique live slug is `(tenant_id, slug)` where not deleted. Live slugs do not clash. Two deleted `test` shops stay fine.

**Blocker:** `recipient_profiles_tenant_phone_uidx` on `(tenant_id, phone)`. Phone `01777777777` exists on both 10 and 11. Copy cannot set both to 15. Script skips colliding phones and reports them.

Trigger `trg_shop_orders_set_parent_tenant_id` / `trg_shops_set_parent_tenant_id` (`set_shop_parent_tenant_id`): if you `UPDATE tenant_id` to 15, it sets `parent_tenant_id` from `tenants.parent_id` of 15 → **null**. The copy script uses `session_replication_role = replica` so that trigger does not run.

### B. `parent_tenant_id` only — no copy; later **rename** column to `tenant_id`

These already store warehouse **15** in `parent_tenant_id`. There is no `tenant_id` to fill.

| Table | Rows | parent=15 |
| :--- | ---: | ---: |
| `products` | 10844 | 10844 |
| `global_stocks` | 60 | 60 |
| `global_shipment_item_outcomes` | 249 | 249 |
| `global_shipment_cost_entries` | 42 | 38 |
| `global_shipment_sections` | 20 | 18 |
| `global_shipments` | 17 | 15 |
| `profiles` | 48 | 35 |
| `notifications` | 30 | 30 |
| `bills` | 26 | 26 |
| `bill_lines` | 49 | 49 |
| `bill_settlements` | 19 | 19 |
| `vendors` | 12 | 9 |
| `catalog_refresh_log` | 6 | 6 |
| `stock_locations` | 5 | 2 |
| `cargo_companies` | 5 | 2 |
| `batch_code_lists` | 3 | 3 |
| `cashbook_point_pots` | 3 | 3 |
| `cashbook_points` | 3 | 3 |
| `delivery_paper` | 1 | 1 |
| `invoice_brands` | 1 | 1 |
| `tenant_data_purge_logs` | 1 | 1 |
| `global_stock_types` | 6 | 0 |
| `books_exchange_rates` | 0 | 0 |
| `global_shipment_boxes` | 0 | 0 |
| `global_shipment_outcome_vendor_credits` | 0 | 0 |
| `sales_return_items` | 0 | 0 |
| `stock_physical_counts` | 0 | 0 |

View (do not UPDATE): `v_kernel_bill_summaries`. `bills` also has `issued_by_tenant_id` (who issued). Keep that; it is not the books owner.

## 2 — Copy script (dual-column tables)

Rule: only `parent_tenant_id = 15`, and `tenant_id` is a child of 15 (**10 / 11**) or null. Other companies stay. Apply **aborts** if 15 is not root or 10/11 are not its children.

This is **data** SQL, not a migration. Do not put it in `supabase/migrations/`. Do not run `backend:prod` for this.

Do **not** run this on parent-only tables. They have no `tenant_id`.

### Local (already done 2026-11-05)

```bash
docker exec -i supabase_db_brandwala-wholesale-quasar psql -U postgres -d postgres \
  < scripts/sql/tenant_id_copy_parent.sql

docker exec -i supabase_db_brandwala-wholesale-quasar psql -U postgres -d postgres \
  < scripts/sql/tenant_id_copy_parent_apply.sql

docker exec -i supabase_db_brandwala-wholesale-quasar psql -U postgres -d postgres \
  < scripts/sql/tenant_id_copy_parent_verify.sql
```

### Production — run in this order

From the repo root. Linked prod only (`pnpm run env:prod` then `backend:link` if not linked).

**1. Confirm you are on prod, and 15 / 10 / 11 match**

```bash
pnpm run env:prod
pnpm exec supabase db query --linked "
SELECT id, name, parent_id, slug
FROM public.tenants
WHERE id IN (10, 11, 15) OR parent_id = 15
ORDER BY id;
"
```

Expect: **15** BW with `parent_id` empty; **10** and **11** with `parent_id = 15`. If that is wrong, **stop**.

**2. Preview (no writes)**

```bash
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent.sql
```

Read the mismatch counts and the recipient phone clash list. If shops live slugs or order numbers would clash, **stop**.

**3. Apply (writes `tenant_id` → 15)**

```bash
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent_apply.sql
```

Apply aborts unless 15 is root and 10 + 11 are its children. One recipient row per clashing phone is left on the child tenant.

**4. Verify**

```bash
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent_verify.sql
```

Expect: no leftover `shop_orders` / `shops` / brands / categories / demand on 10 or 11 under parent 15. `recipient_profiles` may still show the skipped phone. Other companies (not 15) must still be untouched.

**5. After prod copy** — Run **`pnpm run backend:prod`** (migrations **1–10**, including `2026110521*` and `20261106120000_tenant_id_phase10_cleanup.sql`), then **`pnpm run backend:types`**, then **`pnpm run frontend:prod`**. See [Phase 11](#phase-11--prod-release--stragglers--left). Until then, prod schema and deployed app lag local.

## 3 — RPCs: `p_parent_tenant_id` → `p_tenant_id`

Local `pg_proc`: **47** functions took `parent_tenant` in **args** at inventory time; count drops as phases land. **318** function bodies still mention column `parent_tenant_id` (filters, inserts, helpers) until **phase 8**.

Rename args in schema + migration (Postgres **cannot** rename a parameter in place — `DROP FUNCTION` then `CREATE`, SQLSTATE 42P13). Then `pnpm run backend:types:local`. Web callers pass `p_tenant_id`.

### Done — phase 5 (money)

Migration: `20261105218000_tenant_id_phase5_bills_pays_rpc_args.sql`. Schemas: `supabase/schemas/bills_pays/*` + matching bodies in `public.sql`.

- `list_bills_desk_page`, `list_bills_for_source`, `list_pays_for_source`, `list_open_on_profile`, `list_books_exchange_rates`
- `_kernel_claim_pay_idempotency`, `_kernel_finalize_pay_idempotency`, `_kernel_ensure_cashbook_point_pot`
- `_upsert_shipment_ap_bill` (all overloads), `record_ledger_transaction` (`p_operating_tenant_id` unchanged), `resolve_dropship_courier_ap_bill_id`
- Web: `web/src/modules/bills_pays/repositories/billsRepository.ts`, `cashbookRepository.ts` (`.rpc` args only)

Column filters on `bills.parent_tenant_id` / profile `parent_tenant_id` in other modules are **unchanged** until phase 8.

### Done — phase 6 (stock / procurement)

Migration: `20261105219000_tenant_id_phase6_stock_procurement_rpc_args.sql`. Spine: `_stock_spine_upsert_receive_lot` (also mirrored in `20261105120500_post_shipment_internal_spine.sql` for reference).

- `_assert_parent_warehouse_tenant`, `_can_view_parent_warehouse_stock`, `_can_view_stock_locations`
- `_validate_stock_location_nesting` (3rd arg only; `p_parent_location_id` unchanged)
- `assign_shipment_to_child`, `bulk_allocate_shipment_stock`, `can_act_on_parent_tenant_stock`, `can_act_on_stock_movement_context`
- `create_shipment_draft`, `list_child_procurement_lines`, `list_procurement_shop_order_lines`, `list_stock_locations`, `upsert_stock_location`, `upsert_global_stock_allocation`, `hold_shop_grade_stock_for_order` (`p_shop_tenant_id` unchanged)
- Web: `globalShipmentRepository.ts`, `stockLocationRepository.ts`; `globalRepository.ts` → `upsert_global_stock_allocation` with `p_tenant_id` (replaces stale `upsert_child_stock_allocation` call)

`mapStockNetworkRow.ts` maps table column `parent_tenant_id` — not an RPC arg (phase 8).

### Done — phase 7 (args)

Migration: `20261105220000_tenant_id_phase7_remaining_rpc_args.sql`. Guard RPCs (`can_manage_products_for_parent`, `can_view_products_for_parent`, `user_can_manage_parent_tenant`) required `DROP … CASCADE` + RLS policy restore (42 policies). Fixed `vendors_select` to pass `parent_tenant_id` into `user_can_manage_parent_tenant`.

- Shop/order list RPCs: dropped unused `p_parent_tenant_id`; `list_shops_app_page`: `p_catalog_tenant_id`
- `get_app_dashboard_bundle`, `list_child_tenant_refs`: `p_tenant_ids`
- Guards, purge, catalog log, profile, network, cash circulation: `p_tenant_id`
- `notification_inbox_scope_matches`: 2nd arg `p_books_tenant_id`; redeployed inbox list/count/mark-read RPCs
- Web: `shopOrderRepository.ts`, `catalogRefreshRepository.ts`, `appDashboardBundleRepository.ts`, `tenantRepository.ts`

### Done — phase 8a (columns)

Migration: `20261105221000_tenant_id_phase8a_products_catalog_log.sql`. `ALTER TABLE … RENAME COLUMN` on `products` and `catalog_refresh_log`; redeployed ~52 RPCs touching product catalog scope + product RLS policies; index/FK renames.

- Web: `productRepository.ts`, `catalogRefreshByVendor.ts`, `ProductBasedCostingFileHeader.vue`

### Done — phase 8b (columns)

Migration: `20261105222000_tenant_id_phase8b_stock_procurement_columns.sql`. Renamed `parent_tenant_id` → `tenant_id` on `global_stocks`, `global_shipments`, `global_shipment_*`, `stock_locations`, `cargo_companies`, `batch_code_lists`, `global_stock_types`, `global_stock_allocations` (if present). Redeployed 78 RPCs that reference warehouse/shipment `tenant_id`; RLS on 8b tables. Web: `web/src/modules/procurement_stock/**`, `web/src/modules/global/**` (allocations + stock network).

### Done — phase 8c (columns)

Migration: `20261105223000_tenant_id_phase8c_bills_profiles_vendors.sql`. Renamed columns on `bills`, `bill_lines`, `bill_settlements`, `books_exchange_rates`, `cashbook_point_pots`, `cashbook_points`, `invoice_brands`, `profiles`, `vendors`, `sales_return_items`; compat views + `v_kernel_bill_summaries`; 48 RPCs + RLS. Web: `bills_pays`, `sales_invoice`, `vendor`, `after_sales` stubs, `wallet` types.

### Done — phase 8d (columns)

Migration: `20261105224000_tenant_id_phase8d_notifications_stragglers.sql`. `notifications`, `tenant_data_purge_logs`; notification inbox RPCs; web `notifications/types.ts`.

### Phase 8 complete (local)

Declarative `supabase/schemas/` no longer references column `parent_tenant_id`. **Live DB** may still have stragglers (`delivery_paper`, `stock_physical_counts`, dual `preorder_demand` if present) until phase **11d**. Generated types mirror live DB, not only declarative schema.

## 4 — Python / Makefile (flag → `--tenant-id`)

**Done (phase 9):** write `tenant_id`; CLI `--tenant-id`; WTS/ELF use `--inserted-by-tenant-id` for child scope. Numeric defaults in Makefile/env are **this env’s flags**, not library literals.

| Path | Notes |
| :--- | :--- |
| `python/Makefile` | `PC_SYNC_FLAGS`, `WTS_SYNC_FLAGS` use `--tenant-id` / `--inserted-by-tenant-id` |
| `python/scripts/uk/catalog_refresh_lib.py` | `--tenant-id` only |
| `python/scripts/uk/product_sync_lib.py` | REST filter `tenant_id=eq.` |
| `python/scripts/uk/sync_pc_products_to_supabase.py` | `--tenant-id` books scope |
| `python/scripts/uk/sync_wts_products_to_supabase.py` | `--tenant-id` 15; `--inserted-by-tenant-id` 10 |
| `python/scripts/uk/sync_scraped_pc_to_supabase.py` | via lib |
| `python/scripts/uk/remap_elf_product_keys.py` | |
| `python/scripts/uk/check_wts_duplicate_barcodes.py` | |
| `python/scripts/uk/export_wts_data.py` | log / refresh |
| `python/scripts/uk/export_elf_data.py` | |
| `python/scripts/uk/export_pricecheck_scraper.py` | |
| `python/scripts/uk/export_koba_retail_data.py` | Makefile uses **10**, not 15 |
| `python/scripts/uk/export_koba_wholesale_data.py` | Makefile uses **10** |
| `python/pc_uploader/app.py` | builds sync flags |
| `python/wts_uploader/app.py` | builds sync flags |

Also: `scripts/sql/document_numbering_*.sql` (shipment counters group `global_shipments.parent_tenant_id`); `scripts/sql/backfill_shipment_item_ordered_outcomes.sql`.

Koba Makefile `10` is the child company. Confirm in [products upload doc](../features/products/upload-and-release-visibility.md) before forcing 15 on those pipelines.

## Agent phase detail

Each phase: **Goal**, **Files**, **Change**, **Do not**, **Done when**. One agent run = one phase. If a phase would exceed ~3 files of web **or** a huge SQL blast, split by the file list below, not by inventing new meaning.

### Phase 0 — Prod data copy — **local done (prod left)**

**Goal:** Dual-table `tenant_id` becomes 15 **only** where `parent_tenant_id = 15` (that parent’s children, or null). No other `parent_tenant_id`.

**Files:** `scripts/sql/tenant_id_copy_parent.sql` → `_apply.sql` → `_verify.sql` (run only).

**Change:** Human runs [Prod SQL sequence](#prod-sql-sequence). Scripts already filter `WHERE parent_tenant_id = 15`.

**Do not:** Copy other companies. Do not put these files in `supabase/migrations/`. Do not `backend:prod`.

**Done when:** Verify shows no leftover shop orders/shops/brands/categories/demand on 10/11 under parent 15. Skipped recipient phone is OK.

### Phase 1 — Shop-order create writes warehouse `tenant_id` — **done**

**Goal:** New catalog/dropship orders store warehouse `tenant_id` = `resolve_parent_tenant_id` of the selected shop/cart company — not a hardcoded id, not the child ops company when that company has a parent.

**Files:** `supabase/schemas/public.sql` only (these functions):

- `submit_shop_order_from_cart`
- `submit_dropship_order_from_cart`
- `staff_submit_dropship_order_from_cart`
- `staff_create_dropship_order`

**Change:** After shop/cart load, `v_order_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id)` (or `v_shop.tenant_id` when there is no cart). After phase 4, shops already store warehouse `tenant_id`; still call `resolve_parent_tenant_id`, never a numeric literal. Use `v_order_tenant_id` for `shop_orders.tenant_id`, `parent_tenant_id` on insert, and `generate_shop_order_number`. Leave cart `tenant_id` as the shop’s ops company.

**Do not:** Rename RPC args. Do not drop columns. Do not change list RPCs. Do not write `15` / `10` / `11` in the function body.

**Done when:** An order placed while logged into a child company stores `shop_orders.tenant_id` = that child’s parent (root if the selected company is already the warehouse). Trigger must not null `parent_tenant_id` on a root insert.

**Agent note:** `set_shop_parent_tenant_id` used to set `parent_tenant_id` from `tenants.parent_id` of `new.tenant_id`, which is null on a root. Prefer: `new.parent_tenant_id := coalesce(new.parent_tenant_id, v_parent_id, new.tenant_id)`. Also insert `parent_tenant_id = v_order_tenant_id` (not a literal).

### Phase 2 — Shop-order list/get use `tenant_id` — **done**

**Goal:** Staff lists for the **selected** company match `o.tenant_id = p_tenant_id` (warehouse books id the caller passed), not `o.parent_tenant_id`.

**Files:**

- `list_shop_orders_for_staff`
- `list_shop_orders_staff_page`
- `list_dropship_shop_orders_for_staff`
- any shop_order get/list that uses `v_is_parent_query` / `o.parent_tenant_id`
- `web/src/modules/shop_order/repositories/shopOrderRepository.ts`

**Change:** Filter `o.tenant_id = p_tenant_id`. Stop requiring `p_parent_tenant_id` (keep arg as unused default null for one release, or remove and update TS callers in the same PR if ≤3 web files).

**Do not:** Rename bills/stock RPCs. Do not drop columns.

**Done when:** App order list for the selected warehouse company shows copied + new orders. A child-ops company list is empty or only unmatched leftovers — expected. Pass the current tenant from the app; do not hardcode it.

### Phase 3 — Shops list RPCs — **done**

**Goal:** Shop admin lists warehouse shops via `shops.tenant_id =` the selected tenant (RPC arg), not a hardcoded id.

**Files:** `list_shops`, `list_shops_app_page` (`p_catalog_parent_tenant_id` → `p_catalog_tenant_id` or drop if it meant the warehouse company). Web shops list caller (grep `p_parent_tenant_id` under `web/src/modules/shop_order/`).

**Change:** Same as phase 2: match `s.tenant_id`. After data copy, shops already have warehouse `tenant_id`.

**Do not:** Drop `shops.parent_tenant_id` yet (phase 4). Do not hardcode tenant ids in web or SQL.

**Done when:** Shops page for the selected warehouse company still lists catalog + dropship shops.

### Phase 4 — Drop `parent_tenant_id` on dual-column tables — **done**

**4a done:** `shops` + `shop_orders`. **4b done:** `customer_groups` + `recipient_profiles`. **4c done:** `product_brands` + `product_categories` (`preorder_demand` already tenant-only). **4d done:** `cashbook_accounts`, `cashbook_entries`, `invoice_write_offs`. Points/pots and `bill_lines` / `sales_return_items` stay (phase 8). Unused `p_parent_tenant_id` list RPC args removed (phase 7).

**Goal:** Dual tables have only `tenant_id` (warehouse books company, derived — not a hardcoded id).

**Tables:** `shop_orders`, `shops`, `recipient_profiles`, `product_brands`, `product_categories`, `preorder_demand`, `customer_groups`, `cashbook_accounts`, `cashbook_entries`, `global_invoice_items`, `global_return_items`, `invoice_write_offs`.

**Files:** `supabase/schemas/public.sql` (columns, indexes `idx_shop_orders_parent_tenant_*`, FKs, trigger `trg_shop_orders_set_parent_tenant_id` / `trg_shops_set_parent_tenant_id` / `set_shop_parent_tenant_id` if unused). RLS policies on those tables. Grep `parent_tenant_id` on those table names in RPCs and web:

- `web/src/modules/shop_order/repositories/shopPermissionsRepository.ts`
- `web/src/modules/sales_invoice/repositories/recipientProfileRepository.ts`
- `web/src/modules/sales_invoice/stores/recipientProfileStore.ts`
- `web/src/modules/tenant/composables/useCustomerGroupMutations.ts`
- `web/src/modules/tenant/repositories/tenantRepository.ts`
- `web/src/modules/customer/pages/CustomerOverviewPage.vue`
- `web/src/modules/bills_pays/repositories/cashbookRepository.ts` (dual cashbook rows)

**Change:** Schema sync rename/drop: drop column `parent_tenant_id` on those tables only. Update RPC bodies that still read `o.parent_tenant_id`. Phase 1 create RPCs use `v_shop.tenant_id` only.

**Do not:** Drop `parent_tenant_id` on bills, stocks, products, vendors, profiles (parent-only tables). Do not drop `tenants.parent_id`.

**Done when:** Grep those 12 tables has no `parent_tenant_id`. Types regenerated. Shop create + list still work.

### Phase 5 — Bills/pays RPC args — **done**

**Goal:** Money RPCs take `p_tenant_id` = selected warehouse company. **Column still `parent_tenant_id`.** Web passes current tenant; never a literal id.

**Files (SQL):** `list_bills_desk_page`, `list_bills_for_source`, `list_pays_for_source`, `list_open_on_profile`, `list_books_exchange_rates`, `_kernel_*`, `_upsert_shipment_ap_bill`, `record_ledger_transaction` (keep `p_operating_tenant_id` as child/ops), `resolve_dropship_courier_ap_bill_id`.

**Files (web):** `billsRepository.ts`, `cashbookRepository.ts` (RPC args). Column/UI `parent_tenant_id` elsewhere (invoice list filters, after_sales stub, PBC profile insert) stays until phases **7** / **8**.

**Change:** Replace function with new arg name `p_tenant_id`. Body still `WHERE parent_tenant_id = p_tenant_id`. Update TS `rpc('…', { p_tenant_id })`.

**Do not:** Rename the bills column yet (phase 8). Do not change `issued_by_tenant_id`.

**Done when:** Bills desk loads for the selected warehouse company. `pnpm run backend:types:local`.

**Shipped:** migration `20261105218000_tenant_id_phase5_bills_pays_rpc_args.sql` (`DROP FUNCTION` + recreate; redeploy callers that use named `record_ledger_transaction` args).

### Phase 6 — Stock / procurement RPC args — **done**

**Goal:** Same as 5 for warehouse stock.

**Files (SQL):** `_assert_parent_warehouse_tenant`, `_can_view_parent_warehouse_stock`, `_can_view_stock_locations`, `_stock_spine_upsert_receive_lot`, `_validate_stock_location_nesting`, `assign_shipment_to_child`, `bulk_allocate_shipment_stock`, `can_act_on_parent_tenant_stock`, `can_act_on_stock_movement_context`, `create_shipment_draft`, `list_child_procurement_lines`, `list_procurement_shop_order_lines`, `list_stock_locations`, `upsert_global_stock_allocation`, `upsert_stock_location`, `hold_shop_grade_stock_for_order` (`p_shop_tenant_id` stays until shops store warehouse `tenant_id` only).

**Files (web):** `globalShipmentRepository.ts`, `stockLocationRepository.ts`, `globalRepository.ts` (`upsert_global_stock_allocation`). Other procurement pages use column `parent_tenant_id` or resolved tenant ids until phase 8; `mapStockNetworkRow.ts` is column-only.

**Change:** Arg rename only; SQL column still `parent_tenant_id`. Keep `p_child_tenant_id` as the child/ops company the caller selected (not a hardcoded id).

**Do not:** Rename `global_stocks.parent_tenant_id` yet. Do not hardcode tenant ids.

**Done when:** Shipments / locations / stock list for the selected warehouse company work.

**Shipped:** migration `20261105219000_tenant_id_phase6_stock_procurement_rpc_args.sql`.

### Phase 7 — Remaining RPC args — **done**

**Goal:** No public RPC arg named `p_parent_tenant_id` / `p_parent_tenant_ids`.

**Shipped:** migration `20261105220000_tenant_id_phase7_remaining_rpc_args.sql`.

**Files (web):** `shopOrderRepository.ts`, `catalogRefreshRepository.ts`, `appDashboardBundleRepository.ts`, `tenantRepository.ts` (purge / child refs). No changes required in `productRepository.ts`, vendor repos, or `notifications/types.ts`.

**Change:** Arg → `p_tenant_id` / `p_tenant_ids` / `p_catalog_tenant_id` / `p_books_tenant_id` (notification scope). Function **names** unchanged.

**Done when:** Grep `p_parent_tenant_id` in `web/src/modules` empty; types regen’d.

### Phase 8 — Rename parent-only **columns** — **done (8a–8d)**

**Goal:** Books/stock/product rows use column `tenant_id` (same values as before; no hardcoded ids in code).

**8a:** `20261105221000_tenant_id_phase8a_products_catalog_log.sql` — `products`, `catalog_refresh_log`.

**8b:** `20261105222000_tenant_id_phase8b_stock_procurement_columns.sql` — stock/procurement tables (§3 Done — phase 8b).

**8c:** `20261105223000_tenant_id_phase8c_bills_profiles_vendors.sql` — bills/money/profiles/vendors/points (see §3 Done — phase 8c).

**8d:** `20261105224000_tenant_id_phase8d_notifications_stragglers.sql` — `notifications`, `tenant_data_purge_logs` (see §3 Done — phase 8d).

**Done when (full phase 8):** Parent-only columns renamed; types regen’d. Smoke: product list, stock list, bill list, vendor list, catalog refresh log, notification inbox.

### Phase 9 — Python / Makefile / leftover scripts — **done locally**

**Goal:** Pipelines write/filter `tenant_id`, flag `--tenant-id` (alias `--parent-tenant-id` one release).

**Files:** list in [§4](#4--python--makefile-flag--tenant-id). Plus `scripts/sql/document_numbering_*.sql`, `scripts/sql/backfill_shipment_item_ordered_outcomes.sql`.

**Change:** REST `parent_tenant_id=eq.` → `tenant_id=eq.`. WTS `--tenant-id` used as inserted-by/child — rename that flag to `--inserted-by-tenant-id` so it does not collide with warehouse `--tenant-id`. Pass ids from env/Make vars, never literals in library code. **Koba Makefile child id:** confirm in [upload-and-release-visibility](../features/products/upload-and-release-visibility.md) before changing; do not guess.

**Do not:** Point Koba at the warehouse company unless that doc says Koba books are the parent. Do not hardcode tenant ids in Python.

**Done when:** PC/WTS sync dry-run against local uses `tenant_id`. (`make -C python pc-sync-dry` uses local env + `--dry-run`.)

### Phase 10 — Cleanup + docs — **done locally**

**Goal:** No product `parent_tenant_id` except `tenants.parent_id`.

**Files:** leftover trigger/index; [kernel-schema](../features/bills_pays/kernel-schema.md); [bills-desk](../features/bills_pays/bills-desk.md); [stock-spine](../kernel/stock-spine.md); [upload-and-release-visibility](../features/products/upload-and-release-visibility.md); shop_order / procurement / products / customer / after_sales / notifications `spec.md` if they name the column; this file (mark phases done). `scripts/generate-module-section.mjs`. After-sales mocks `web/src/modules/after_sales/fixtures/mockAfterSales.ts`.

**Change:** Delete dead aliases. Docs say books owner = `tenant_id`. SQL: `20261106120000_tenant_id_phase10_cleanup.sql` renames books RPCs; deprecated `*_parent_tenant_*` SQL wrappers remain in DB until a later drop (not in declarative schema).

**Done when:** Grep `parent_tenant_id` in `web/src` (hand-written; generated `database.types.ts` may list deprecated wrapper RPCs) + `supabase/schemas/` + `python/` is empty (ignore `supabase/migrations/`). `tenants.parent_id` still exists.

### Phase 11 — Prod release + stragglers — **left**

**Goal:** Production matches local cutover; no operational reliance on deprecated wrappers; straggler tables aligned with `tenant_id`.

**11a — Prod Phase 0 (human)** — checklist

| Step | Action | Stop if |
| :---: | :--- | :--- |
| 0 | `pnpm run env:prod` then `pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_preflight.sql` | Tenant tree not 15 root / 10+11 children |
| — | Read `decision` row | — |
| SKIP | Log “Phase 0 skipped — dual column already dropped”; continue **11b** | — |
| RUN | [Prod SQL sequence](#prod-sql-sequence) steps **1 → 2 → 3 → 4** | Preview shows bad clashes; apply raises; verify shows `n > 0` on shops/orders/brands (except known recipient phones) |
| After | Do **not** deploy app before **11b**; copy only fixes `tenant_id` on dual tables | — |

Preflight replaces manual “grep prod for `shops.parent_tenant_id`”. Apply script still hard-checks 10/11/15 shape and aborts if wrong.

**11b — Push backend**  
`pnpm run backend:prod` then `pnpm run backend:types`. Confirm migrations through `20261106120000_tenant_id_phase10_cleanup.sql` applied.

**11c — Push frontend**  
`pnpm run frontend:prod` after **11b**.

**11d — Straggler columns (code + migration)**  
Rename `parent_tenant_id` → `tenant_id` on tables still using old name in live DB (at minimum **`delivery_paper`**, **`stock_physical_counts`**; verify **`preorder_demand`** for leftover dual column). Patch declarative schema (`public.sql` or split domain), redeploy delivery-paper RPCs/RLS that reference `delivery_paper.parent_tenant_id` (see `20261104110000_delivery_paper_and_preorder_demand_placements.sql` patterns). `pnpm run backend:local` → `backend:prod`.

**11e — RPC / OUT cleanup (optional but recommended)**  
Drop deprecated wrappers (`resolve_parent_tenant_id`, …) after grep confirms no `prosrc` references. Redeploy list RPCs whose `RETURNS TABLE` still exposes `parent_tenant_id` (DROP FUNCTION + CREATE, or new migration slice — avoid 42P13). Rename FK/index suffixes `_parent_tenant_id_*` → `_tenant_id_*` if types hygiene matters.

**11f — Prod smoke**  
App: shop create/list, bills desk, stock network search, delivery paper flow, notification inbox, catalog refresh log. Python: `make -C python pc-sync-dry` against prod env only if human approves writes path.

**Done when:** Phase 0 verified on prod (or documented skip); **11b–c** deployed; smoke green; no P0 errors on child-tenant shop flows; straggler tables (**11d**) migrated or explicitly deferred with doc note.
