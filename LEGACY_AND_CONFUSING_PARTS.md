# Legacy & Confusing Parts Guide (Junior Developer Survival Guide)

This project has evolved through multiple major rewrites (multi-tenant hierarchy changes, a new money/billing kernel, and V1 → V2 feature migrations). Because old and new code still coexist, implementing a "simple" flow often feels harder than it should.

This guide explains **what is confusing, why it looks like that, and what you should use instead**.

---

## 1. `bills_pays` (Bridge / Legacy) vs. `money_kernel_v2`

### Why it's confusing
There are still **two** billing/payment layers coexisting in `bills_pays` and the database:

1. **Legacy / Bridge layer (`bills_pays` + `public.bills` view with `spine: 'legacy' | 'kernel'`):**
   - `web/src/modules/bills_pays/repositories/invoiceRepository.ts` (moved from the old `sales_invoice` module) is still wrapped by `billsRepository.ts` and queries `supabase.from('bills')` using legacy column names (`invoice_no`, `invoice_type`, `invoice_status`, `invoice_date`) and legacy foreign-key names (`tenants!global_invoices_issued_by_tenant_id_fkey`).
   - `public.bills` and `public.bill_lines` are **no longer physical tables**—they were dropped and replaced by SQL compatibility `VIEW`s over `money_kernel.bills` (see `supabase/schemas/bills_pays/99_legacy_kernel_cutover.sql` and `20261119233000_retire_parent_tenant_id_columns.sql`).
   - Frontend files like `billsRepository.ts`, `paysRepository.ts`, `BillDetailPage.vue`, `BillAdjustmentComposePage.vue`, and `ProfilePayDetailDialog.vue` still branch on `spine === 'kernel'` vs `'legacy'` (or `'desk'`).
   - Legacy tables (`cashbook_entries`, `pay_allocations`, `pay_instruments`, `money_purposes`, `invoice_write_offs`, `sales_invoice_counters`) are marked `DEPRECATED` in `99_legacy_kernel_cutover.sql` with client `INSERT/UPDATE/DELETE` revoked.

2. **`money_kernel_v2` (`money_kernel.*` schema):**
   - The new source of truth for money lives in `supabase/schemas/money_kernel_v2/` and is called from `web/src/modules/bills_pays/repositories/moneyKernelRepository.ts` via RPCs listed in `moneyKernelTargets.ts` (`rpc_create_bill`, `rpc_issue_bill`, `rpc_pay_bill`, `rpc_pay_bills`, `rpc_deposit`, `rpc_withdraw`, etc.).
   - Notice `moneyKernelRepository.ts` uses `const db = supabase as any;` because some RPCs/types aren't in generated `database.types.ts`.

### Rule of thumb
- For **new** money/billing features, use `bills_pays` + `money_kernel_v2` (`rpc_*` RPCs), **not** legacy tables like `cashbook_entries` / `pay_allocations`.
- When reading `invoiceRepository.ts`, remember that `invoice_*` names are legacy terminology for **bills**.

---

## 3. Currency & Multi-Currency / FX Confusion

### Why it's confusing
Different modules represent, store, and format money in completely different ways:

- **BDT-first global helpers:**
  - `web/src/boot/currency.ts` registers `$formatBdt` globally.
  - `web/src/utils/currency.ts` has `formatAmountBdt` / `formatBdtTaka` (hardcodes `৳` and Indian digit grouping) alongside `formatSettlementCurrencyAmount` (handles `BDT`, `GBP`, `USD`, `EUR` and explicitly avoids `৳` for non-BDT).
- **Shop orders have TWO currencies on the same order (Purchase vs. Sell):**
  - `web/src/modules/shop_order/utils/resolveCatalogOrderCurrency.ts` resolves a **purchase/cargo currency** (defaults to `£`, preferring item `cost_price_currency_symbol` over `order.shop_buy_currency_symbol`) separately from a **customer sell currency** (defaults to `৳`, from `order.shop_sell_currency_symbol`).
  - `coerceCatalogPrice` in `web/src/modules/shop_order/utils/catalogPriceUtils.ts` has to accept raw numbers, JSON strings, or objects with `amount`, `unit_price_amount`, or `sell_price_amount`.
- **Bills & Cashbook have 3-way FX:**
  - In `web/src/modules/bills_pays/composables/useApPayoutFxFields.ts`, paying a bill can involve three currencies at once:
    1. **Payment currency** (bill face currency)
    2. **Source currency** (the cashbook pot currency)
    3. **Books currency** (company ledger currency, usually `BDT`)
  - That's why `public.bills` has `currency_code`, `txn_currency_code`, `txn_total_amount`, and `books_exchange_rate`, and why `useBooksExchangeRateQuery.ts` fetches FX rates per `parentTenantId` + `quoteCurrencyCode`.
- **Thrift has its own formatter:** `web/src/modules/thrift/currency/utils/formatMoney.ts`.

### Rule of thumb
- Always ask: *"Is this amount in **purchase currency** (e.g. GBP/CNY), **settlement/transaction currency**, or **books currency** (BDT)?"*
- Don't use `formatBdtTaka` / `$formatBdt` on foreign-currency amounts—use `formatSettlementCurrencyAmount` in `bills_pays` or the module's currency resolver.

---

## 4. Database Schema & Migrations Maze

### Why it's confusing
- **`supabase/schemas/public.sql` is ~3 MB** (a giant monolithic dump) and sits next to backup files (`public.sql.bak`, `public.sql.pre-so3`).
- **Partially split schemas:** `supabase/schemas/bills_pays/` contains 20+ organized `.sql` files, **but it is NOT listed in `schema_paths` in `supabase/config.toml`**. Right now `config.toml` only loads `_extensions.sql`, `public.sql`, `money_kernel_v2/*`, and `reporting/01_customer_report_rpcs.sql`.
- **340+ migrations:** `supabase/migrations/` has over 340 files (including future-dated timestamps like `20261124...` and `20270918...` used as ordered sequence numbers), with many small hotfix/compat migrations layered on top of each other.

### Rule of thumb
- Check `supabase/config.toml` (`schema_paths`) to know which declarative schema files are actually active.
- For `bills_pays` SQL, read `supabase/schemas/bills_pays/README.md` before editing—some files are archive references while `05_money_spine.sql` and `money_kernel_v2/` are active sources.

---

## 5. Overlapping Frontend Modules (V1 vs. V2 & Duplicate Concepts)

### Why it's confusing
It's often unclear which folder owns a feature because old and new versions sit side by side:

- **Costing (2 separate modules):**
  - `web/src/modules/costingFile/` (11 pages for Admin/Customer/Staff/Viewer costing files)
  - `web/src/modules/product_based_costing/` (`ProductBasedCostingPage.vue`, `ProductBasedCostingFileDetailsV2Page.vue`)
- **People / Parties (split across 5+ modules):**
  - `people/` (`PeoplePage.vue` with tabs for `tenant`, `customer`, `curia`, `cargo`, `vendor`, `investor`, `end_customer`)
  - `customer/` (`CustomerHubPage`, `CustomerOverviewPage`, `RecipientProfilesPage`)
  - `vendor/` (`VendorsPage`, `VendorDetailsPage`)
  - `investor_capital/` & `investor_portal/`
  - `shop_order/` (`DropshipMerchantsPage`, `DropshipCouriersPage`)
  - Under the hood, most of these represent rows in `profiles` with different types/roles.
- **Shop Orders & Dropship (`web/src/modules/shop_order/pages/`):**
  - Contains 40+ pages mixing storefront, cart, checkout, manual orders, and both V1 and V2 dropship pages (`DropshipOrdersPage.vue`, `DropshipManagementPage.vue`, `DropshipOrderDetailV2Page.vue`, etc.).
- **Global data:** Split across `web/src/modules/global/`, `web/src/modules/global_reference/` (currencies, markets, payment methods, UoMs), and `web/src/modules/products/`.

### Rule of thumb
- Before building a new page or composable, check `web/src/modules/navigation/moduleRegistry.ts` to see which route and module are currently active.

---

## Quick Checklist Before Starting a New Flow

1. **Check the route first:** Look in `moduleRegistry.ts` to make sure you're working in the active module.
2. **Use `tenant_id`:** Don't add new `parent_tenant_id` or company-hierarchy references.
3. **Use the new money kernel:** For anything touching bills, payments, or cashbook, target `bills_pays` + `money_kernel_v2` (`rpc_*`), not legacy `cashbook_entries` / `pay_allocations`.
4. **Verify currency context:** Explicitly track whether a field is in **books currency (BDT)**, **purchase currency**, or **settlement currency**.
