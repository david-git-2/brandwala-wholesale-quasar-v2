# Tenant id cutover (`parent_tenant_id` → `tenant_id`)

## Prod SQL sequence

Linked prod. Run **in this order**. Stop if a step looks wrong.

```bash
pnpm run env:prod

# 1 — confirm 15 is parent of 10 and 11
pnpm exec supabase db query --linked "
SELECT id, name, parent_id, slug
FROM public.tenants
WHERE id IN (10, 11, 15) OR parent_id = 15
ORDER BY id;
"

# 2 — preview (no writes)
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent.sql

# 3 — apply (writes tenant_id = 15)
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent_apply.sql

# 4 — verify
pnpm exec supabase db query --linked -f scripts/sql/tenant_id_copy_parent_verify.sql
```

Not a migration. Do not run `backend:prod` for this.

## Agent phases (one phase per run)

Do **not** mix phases. After SQL: `pnpm run backend:local` (not reset) then `backend:types:local`. Grep one symbol in `supabase/schemas/`; do not full-read `public.sql` or `database.types.ts`. Never rename `tenants.parent_id`. Never write child **10 / 11** onto warehouse rows.

| Phase | Ship | Depends |
| :--- | :--- | :--- |
| **0** | Prod data copy (SQL scripts above) | — |
| **1** | Shop-order **create** writes `tenant_id = 15` | 0 |
| **2** | Shop-order **list/get** use `o.tenant_id` | 1 |
| **3** | Shops list RPCs + web use `tenant_id` | 0 |
| **4** | Dual-table readers; drop `parent_tenant_id` on dual tables | 1–3 |
| **5** | Bills/pays RPC arg `p_parent_tenant_id` → `p_tenant_id` (column name unchanged) | 0 |
| **6** | Stock/procurement RPC args same rename | 0 |
| **7** | Remaining RPC args (products, notify, purge, dashboard) | 5–6 |
| **8** | Rename column `parent_tenant_id` → `tenant_id` on parent-only tables (split by domain if huge) | 5–7 |
| **9** | Python / Makefile flags; leftover SQL scripts | 8 |
| **10** | Drop any leftover `parent_tenant_id`; kernel docs | 4 + 8 + 9 |

Phase detail is at the bottom: [Agent phase detail](#agent-phase-detail).

### Domain coverage (must all land in a phase)

| Domain | Tables / notes | Phase |
| :--- | :--- | :--- |
| Shop orders + dropship | `shop_orders` create/list; desk | **1–2**, drop col **4** |
| Shops + permissions + catalog refresh UI | `shops`; `shopPermissionsRepository`; `catalogRefreshRepository` | **3**, **7**, drop **4** / col **8a** |
| Products + brands/categories | `products` (parent-only); dual `product_brands`, `product_categories` | dual **4**; products **8a** + **9** |
| Pre-order / PBC | `preorder_demand` dual; PBC header creates **profile** via `parent_tenant_id` | demand **4**; profile write **5/7** + col **8c** |
| Procurement / stock / cargo / batch / locations / delivery paper | `global_stocks`, shipments, outcomes, locations, `cargo_companies`, `batch_code_lists`, `delivery_paper`, stock types | args **6**; cols **8b** |
| Money: bills, pays, cashbook, brands, FX | `bills`, `bill_lines`, `bill_settlements`, cashbook dual + points, `invoice_brands`, `books_exchange_rates`; `issued_by_tenant_id` stays | args **5**; dual cashbook **4**; cols **8c** |
| Customers / groups / recipients / profiles | `customer_groups`, `recipient_profiles` dual; `profiles` parent-only | dual **4**; `upsert_profile_for_party` **7**; cols **8c** |
| Vendors | `vendors` | **8c** + vendor web |
| After-sales | pages/dialogs/stubs write `parent_tenant_id` on bills/returns | **5** + **8c** (no own table) |
| Notifications | `notifications`; inbox RPCs | args **7**; col **8** |
| Dashboard | `get_app_dashboard_bundle` | **7** |
| Tenant purge / child refs | purge RPCs | **7** |
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
| Scripts | [preview](../../scripts/sql/tenant_id_copy_parent.sql) · [apply](../../scripts/sql/tenant_id_copy_parent_apply.sql) · [verify](../../scripts/sql/tenant_id_copy_parent_verify.sql) |

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

**5. After prod copy** — RPC / Python rename is a later PR. Create RPCs still write child `tenant_id` until those functions change; new orders can drift back to 10/11 until slice 2.

## 3 — RPCs: `p_parent_tenant_id` → `p_tenant_id`

Local `pg_proc`: **47** functions take `parent_tenant` in **args**. **318** function bodies mention `parent_tenant_id` (filters, inserts, helpers).

After copy, shop-order **list** RPCs can match `o.tenant_id = 15` instead of `o.parent_tenant_id`.

Rename args in a later schema pass (Postgres cannot rename a parameter in place; replace the function). Then `pnpm run backend:types:local`. Web callers pass `p_tenant_id`.

### Args today (local)

Helpers (keep meaning “warehouse company”, rename arg):

- `_assert_parent_warehouse_tenant`
- `_can_view_parent_warehouse_stock`
- `_can_view_stock_locations`
- `_kernel_claim_pay_idempotency`
- `_kernel_ensure_cashbook_point_pot`
- `_kernel_finalize_pay_idempotency`
- `_stock_spine_upsert_receive_lot`
- `_upsert_shipment_ap_bill` (4 overloads)
- `_validate_stock_location_nesting`
- `can_act_on_parent_tenant_stock`
- `can_act_on_stock_movement_context`
- `can_manage_products_for_parent`
- `can_view_products_for_parent`
- `parent_tenant_has_module_action`
- `user_can_manage_parent_tenant`

Public / desk:

- `assign_shipment_to_child` — keep `p_child_tenant_id`; warehouse arg → `p_tenant_id`
- `bulk_allocate_shipment_stock`
- `create_shipment_draft`
- `get_app_dashboard_bundle` (`p_parent_tenant_ids` array)
- `get_parent_cash_circulation`
- `hold_shop_grade_stock_for_order` (`p_shop_tenant_id` stays until shops copy)
- `list_bills_desk_page`
- `list_bills_for_source`
- `list_books_exchange_rates`
- `list_catalog_refresh_log`
- `list_child_procurement_lines`
- `list_child_tenant_ids` / `list_child_tenant_refs`
- `list_dropship_shop_orders_for_staff`
- `list_open_on_profile`
- `list_pays_for_source`
- `list_procurement_shop_order_lines`
- `list_shop_orders_for_staff`
- `list_shop_orders_staff_page`
- `list_shops`
- `list_shops_app_page` (also `p_catalog_parent_tenant_id`)
- `list_stock_locations`
- `notification_inbox_scope_matches`
- `preview_tenant_data_purge` / `purge_tenant_operational_data`
- `record_ledger_transaction` (`p_operating_tenant_id` stays = child/ops)
- `resolve_dropship_courier_ap_bill_id`
- `resolve_notification_recipient_user_ids`
- `transfer_network_owner`
- `upsert_global_stock_allocation`
- `upsert_profile_for_party`
- `upsert_stock_location`

Create RPCs (`submit_shop_order_from_cart`, `submit_dropship_order_from_cart`, `staff_submit_dropship_order_from_cart`, `staff_create_dropship_order`) do **not** take parent as an arg. They write `tenant_id` from the **shop/cart** (10/11). After copy, change those inserts to `coalesce(shop.parent_tenant_id, shop.tenant_id)` so new orders land on **15**.

## 4 — Python / Makefile (flag → `--tenant-id`)

Today they write `parent_tenant_id` and pass `--parent-tenant-id`. After column rename, write `tenant_id` and pass `--tenant-id` (keep old flag as alias for one release).

| Path | Notes |
| :--- | :--- |
| `python/Makefile` | `PC_SYNC_FLAGS`, `WTS_SYNC_FLAGS`, export/sync lines |
| `python/scripts/uk/catalog_refresh_lib.py` | shared `--parent-tenant-id` |
| `python/scripts/uk/product_sync_lib.py` | REST filter `parent_tenant_id=eq.` |
| `python/scripts/uk/sync_pc_products_to_supabase.py` | default 15 |
| `python/scripts/uk/sync_wts_products_to_supabase.py` | default 15; also `--tenant-id 10` (inserted-by / child) |
| `python/scripts/uk/sync_scraped_pc_to_supabase.py` | via lib |
| `python/scripts/uk/remap_elf_product_keys.py` | |
| `python/scripts/uk/check_wts_duplicate_barcodes.py` | |
| `python/scripts/uk/export_wts_data.py` | log / refresh |
| `python/scripts/uk/export_elf_data.py` | |
| `python/scripts/uk/export_koba_retail_data.py` | Makefile uses **10**, not 15 |
| `python/scripts/uk/export_koba_wholesale_data.py` | Makefile uses **10** |
| `python/pc_uploader/app.py` | builds sync flags |
| `python/wts_uploader/app.py` | builds sync flags |

Also: `scripts/sql/document_numbering_*.sql` (shipment counters group `global_shipments.parent_tenant_id`); `scripts/sql/backfill_shipment_item_ordered_outcomes.sql`.

Koba Makefile `10` is the child company. Confirm in [products upload doc](../features/products/upload-and-release-visibility.md) before forcing 15 on those pipelines.

## Agent phase detail

Each phase: **Goal**, **Files**, **Change**, **Do not**, **Done when**. One agent run = one phase. If a phase would exceed ~3 files of web **or** a huge SQL blast, split by the file list below, not by inventing new meaning.

### Phase 0 — Prod data copy

**Goal:** Dual-table `tenant_id` is 15 where `parent_tenant_id` is 15 (children 10/11 or null).

**Files:** `scripts/sql/tenant_id_copy_parent.sql` → `_apply.sql` → `_verify.sql` (run only).

**Change:** Human runs [Prod SQL sequence](#prod-sql-sequence).

**Do not:** Put these files in `supabase/migrations/`. Do not `backend:prod`.

**Done when:** Verify shows no leftover shop orders/shops/brands/categories/demand on 10/11 under parent 15. Skipped recipient phone is OK.

### Phase 1 — Shop-order create writes warehouse `tenant_id`

**Goal:** New catalog/dropship orders store `tenant_id = 15`, not shop child 10/11.

**Files:** `supabase/schemas/public.sql` only (these functions):

- `submit_shop_order_from_cart`
- `submit_dropship_order_from_cart`
- `staff_submit_dropship_order_from_cart`
- `staff_create_dropship_order`

**Change:** Before insert, `v_order_tenant_id := coalesce(v_shop.parent_tenant_id, v_shop.tenant_id)` (after phase 4, use `v_shop.tenant_id` only). Use it for `shop_orders.tenant_id` and `generate_shop_order_number`. Leave cart `tenant_id` as the shop’s company.

**Do not:** Rename RPC args. Do not drop columns. Do not change list RPCs.

**Done when:** Placing an order on shop tenant 10 writes `shop_orders.tenant_id = 15`. Trigger must not null `parent_tenant_id` (replica / don’t update `tenant_id` in a way that fires wipe — insert with 15; trigger sets parent from `tenants.parent_id` of 15 → **null**. After copy, either accept null parent on new rows or set `parent_tenant_id` explicitly to 15 until phase 4 drops it).

**Agent note:** Today `set_shop_parent_tenant_id` on insert of `tenant_id=15` sets `parent_tenant_id` null. For the overlap, **also insert `parent_tenant_id = 15`** (trigger runs BEFORE insert and overwrites). Fix the trigger in this phase: if `new.tenant_id` is a root tenant, set `parent_tenant_id := new.tenant_id` **or** skip overwrite when `new.parent_tenant_id` is already set. Prefer: `new.parent_tenant_id := coalesce(new.parent_tenant_id, v_parent_id, new.tenant_id)` so warehouse rows keep 15 until drop.

### Phase 2 — Shop-order list/get use `tenant_id`

**Goal:** Staff lists for company 15 match `o.tenant_id = 15`, not `o.parent_tenant_id`.

**Files:**

- `list_shop_orders_for_staff`
- `list_shop_orders_staff_page`
- `list_dropship_shop_orders_for_staff`
- any shop_order get/list that uses `v_is_parent_query` / `o.parent_tenant_id`
- `web/src/modules/shop_order/repositories/shopOrderRepository.ts`

**Change:** Filter `o.tenant_id = p_tenant_id`. Stop requiring `p_parent_tenant_id` (keep arg as unused default null for one release, or remove and update TS callers in the same PR if ≤3 web files).

**Do not:** Rename bills/stock RPCs. Do not drop columns.

**Done when:** App order list for tenant 15 shows copied + new orders. Child 10 staff list is empty or only unmatched leftovers — expected.

### Phase 3 — Shops list RPCs

**Goal:** Shop admin lists warehouse shops via `shops.tenant_id = 15`.

**Files:** `list_shops`, `list_shops_app_page` (`p_catalog_parent_tenant_id` → `p_catalog_tenant_id` or drop if it meant 15). Web shops list caller (grep `p_parent_tenant_id` under `web/src/modules/shop_order/`).

**Change:** Same as phase 2: match `s.tenant_id`. After data copy, shops already have `tenant_id = 15`.

**Do not:** Drop `shops.parent_tenant_id` yet (phase 4).

**Done when:** Shops page for 15 still lists catalog + dropship shops.

### Phase 4 — Drop `parent_tenant_id` on dual-column tables

**Goal:** Dual tables have only `tenant_id` (warehouse 15).

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

### Phase 5 — Bills/pays RPC args

**Goal:** Money RPCs take `p_tenant_id` = warehouse 15. **Column still `parent_tenant_id`.**

**Files (SQL):** `list_bills_desk_page`, `list_bills_for_source`, `list_pays_for_source`, `list_open_on_profile`, `list_books_exchange_rates`, `_kernel_*`, `_upsert_shipment_ap_bill`, `record_ledger_transaction` (keep `p_operating_tenant_id` as child/ops), `resolve_dropship_courier_ap_bill_id`.

**Files (web):** `web/src/modules/bills_pays/repositories/*` (bills, pays, cashbook), `web/src/modules/bills_pays/pages/Bill*.vue`, `web/src/modules/sales_invoice/repositories/invoiceRepository.ts`, `customerProfileRepository.ts`, `web/src/modules/wallet/`, `web/src/modules/after_sales/` (intake + return dialogs + stub), `web/src/modules/product_based_costing/components/ProductBasedCostingFileHeader.vue` (creates profile with `parent_tenant_id`).

**Change:** Replace function with new arg name `p_tenant_id`. Body still `WHERE parent_tenant_id = p_tenant_id`. Update TS `rpc('…', { p_tenant_id })`.

**Do not:** Rename the bills column yet (phase 8). Do not change `issued_by_tenant_id`.

**Done when:** Bills desk loads for 15. `pnpm run backend:types:local`.

### Phase 6 — Stock / procurement RPC args

**Goal:** Same as 5 for warehouse stock.

**Files (SQL):** `_assert_parent_warehouse_tenant`, `_can_view_parent_warehouse_stock`, `_can_view_stock_locations`, `_stock_spine_upsert_receive_lot`, `_validate_stock_location_nesting`, `assign_shipment_to_child`, `bulk_allocate_shipment_stock`, `can_act_on_parent_tenant_stock`, `can_act_on_stock_movement_context`, `create_shipment_draft`, `list_child_procurement_lines`, `list_procurement_shop_order_lines`, `list_stock_locations`, `upsert_global_stock_allocation`, `upsert_stock_location`, `hold_shop_grade_stock_for_order` (`p_shop_tenant_id` stays until shops are 15-only).

**Files (web):** `web/src/modules/procurement_stock/repositories/*` (shipment, stock, cargo, batch, locations, sections, child stock, stock types), stores/composables/pages that pass `parent_tenant_id`, `web/src/modules/global/repositories/globalRepository.ts`, `web/src/modules/global/utils/mapStockNetworkRow.ts`.

**Change:** Arg rename only; SQL column still `parent_tenant_id`. Keep `p_child_tenant_id` as child 10/11.

**Do not:** Rename `global_stocks.parent_tenant_id` yet.

**Done when:** Shipments / locations / stock list for 15 work.

### Phase 7 — Remaining RPC args

**Goal:** No public RPC arg named `p_parent_tenant_id` / `p_parent_tenant_ids`.

**Files:** `can_manage_products_for_parent`, `can_view_products_for_parent`, `list_catalog_refresh_log`, `get_app_dashboard_bundle`, `get_parent_cash_circulation`, `list_child_tenant_ids`, `list_child_tenant_refs`, `notification_inbox_scope_matches`, `parent_tenant_has_module_action`, `preview_tenant_data_purge`, `purge_tenant_operational_data`, `resolve_notification_recipient_user_ids`, `transfer_network_owner`, `upsert_profile_for_party`, `user_can_manage_parent_tenant`. Web: dashboard, notifications, products, tenant, vendor repos that pass the old arg. `web/src/types/database.types.ts` via types gen only.

**Change:** Arg → `p_tenant_id` / `p_tenant_ids`. Function **names** may stay (`user_can_manage_parent_tenant`) until a later rename PR.

**Do not:** Rename columns (phase 8). Do not rename helper function names in the same run unless the caller set is tiny.

**Done when:** Grep `p_parent_tenant_id` in `web/src` (except types if not regen’d yet) is empty. Types regen.

### Phase 8 — Rename parent-only **columns**

**Goal:** Books/stock/product rows use column `tenant_id` (value still 15).

**Tables:** batch_code_lists, bill_lines, bill_settlements, bills, books_exchange_rates, cargo_companies, cashbook_point_pots, cashbook_points, catalog_refresh_log, delivery_paper, global_shipment_*, global_shipments, global_stock_types, global_stocks, invoice_brands, notifications, products, profiles, sales_return_items, stock_locations, stock_physical_counts, tenant_data_purge_logs, vendors. View `v_kernel_bill_summaries`.

**Change:** Declarative schema: `parent_tenant_id` → `tenant_id`. Update every RPC body and RLS that referenced the old column. Unique indexes follow the new name. **Split PRs by domain if the diff is large:** (8a) products + catalog_refresh_log, (8b) global_stocks + shipments + locations, (8c) bills + cashbook points + profiles + vendors.

**Do not:** Drop `issued_by_tenant_id`. Do not collapse `p_operating_tenant_id`. Do not run 8a–8c in one agent run.

**Done when:** Grep `parent_tenant_id` in `supabase/schemas/` is only comments/history or gone. Types regen. One smoke path per domain (product list, stock list, bill list).

### Phase 9 — Python / Makefile / leftover scripts

**Goal:** Pipelines write/filter `tenant_id`, flag `--tenant-id` (alias `--parent-tenant-id` one release).

**Files:** list in [§4](#4--python--makefile-flag--tenant-id). Plus `scripts/sql/document_numbering_*.sql`, `scripts/sql/backfill_shipment_item_ordered_outcomes.sql`.

**Change:** REST `parent_tenant_id=eq.` → `tenant_id=eq.`. WTS `--tenant-id 10` today means inserted-by/child — rename that to `--inserted-by-tenant-id` so it does not collide with warehouse `--tenant-id 15`. **Koba Makefile `10`:** confirm in [upload-and-release-visibility](../features/products/upload-and-release-visibility.md) before changing; do not guess.

**Do not:** Point Koba at 15 unless that doc says Koba books are parent 15.

**Done when:** PC/WTS sync dry-run against local uses `tenant_id`.

### Phase 10 — Cleanup + docs

**Goal:** No product `parent_tenant_id` except `tenants.parent_id`.

**Files:** leftover trigger/index; [kernel-schema](../features/bills_pays/kernel-schema.md); [bills-desk](../features/bills_pays/bills-desk.md); [upload-and-release-visibility](../features/products/upload-and-release-visibility.md); this file (mark phases done). `scripts/generate-module-section.mjs` if it still mentions the old column.

**Change:** Delete dead aliases. Docs say books owner = `tenant_id`.

**Done when:** Grep `parent_tenant_id` in `web/src` + `supabase/schemas/` + `python/` is empty (ignore migrations history).

---

Money/stock kernel docs still say `parent_tenant_id` = books owner until **phase 10**.
