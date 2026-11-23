# Legacy & Confusing Parts Guide (Junior Developer Survival Guide)

This project has evolved through multiple major rewrites (multi-tenant hierarchy changes, a new money/billing kernel, and V1 → V2 feature migrations). Because old and new code still coexist, implementing a "simple" flow often feels harder than it should.

This guide explains **what is confusing, why it looks like that, and what you should use instead**.

---

## 1. Multi-Currency / 3-Way FX

### Why it's confusing
- **Bills & Cashbook have 3-way FX:**
  - In `web/src/modules/bills_pays/composables/useApPayoutFxFields.ts`, paying a bill can involve three currencies at once:
    1. **Payment currency** (bill face currency)
    2. **Source currency** (the cashbook pot currency)
    3. **Books currency** (company ledger currency, usually `BDT`)
  - That's why `money_kernel.bills` has `currency_code`, `txn_currency_code`, `txn_total_amount`, and `books_exchange_rate`, and why `useBooksExchangeRateQuery.ts` fetches FX rates per `tenantId` + `quoteCurrencyCode`.
- **Do not touch `web/src/modules/thrift/`:** It is self-contained with its own currency/formatting (`web/src/modules/thrift/currency/utils/formatMoney.ts`)—leave it as-is and avoid modifying it.

### Rule of thumb
- Always ask: *"Is this amount in **purchase currency** (e.g. GBP/CNY), **settlement/transaction currency**, or **books currency** (BDT)?"*
- Don't use `formatBdtTaka` / `formatAmountBdt` on foreign-currency amounts—use `formatCurrencyAmount` or `formatSettlementCurrencyAmount` from `web/src/utils/currency.ts` with the resolved currency code/symbol.

---

## 2. Database Schema & Migrations Maze

### Why it's confusing
- **`supabase/schemas/public.sql` is ~2.6 MB** (a monolithic dump of the `public` schema, currently being split into domain folders).
- **Partially split schemas:** `supabase/config.toml` (`schema_paths`) currently loads `_extensions.sql`, `public.sql`, `thrift/*`, `costing/*`, `money_kernel_v2/*`, and `reporting/01_customer_report_rpcs.sql`. Other folders like `supabase/schemas/bills_pays/` are **not** listed in `schema_paths`.
- **340+ migrations:** `supabase/migrations/` has over 340 files (including future-dated timestamps like `20261124...` and `20270918...` used as ordered sequence numbers), with many small hotfix/compat migrations layered on top of each other.

### Rule of thumb
- Check `supabase/config.toml` (`schema_paths`) to know which declarative schema files are actually active.
- For `bills_pays` SQL, read `supabase/schemas/bills_pays/README.md` before editing—some files are archive references while `05_money_spine.sql` and `money_kernel_v2/` are active sources.

---

## 3. Legacy Naming & Dense Frontend Modules

### Why it's confusing
- **Dropship Role & Terminology Mapping (UI vs. Legacy DB/Routes):**
  - **Supplier** = `tenant`
  - **Dropshipper** = `customer` (legacy DB/RPCs and some route paths still use `merchant` or `reseller`, e.g., `get_dropship_merchant_billable_charges`, `merchant_payable`, route `/merchants`; frontend pages/composables use `Dropshipper` such as `DropshippersPage.vue`, `useDropshipperPayoutQuery.ts`, `dropshipperWalletRepository.ts`)
  - **Recipient** = `end_customer`
- **Shop Orders & Dropship (`web/src/modules/shop_order/pages/`):**
  - Contains 35 active pages mixing storefront, cart, checkout, manual orders, and dropship pages (`DropshipManagementPage.vue`, `DropshipOrderDetailV2Page.vue`, etc.; 6 unreferenced V1 pages were removed).

### Rule of thumb
- Before building a new page or composable, check `web/src/modules/navigation/moduleRegistry.ts` to see which route and module are currently active (note: `shop_fulfillment` and `shop_dropship` are retired from nav; active order management lives under `shop_order_mgmt`).

---

## Quick Checklist Before Starting a New Flow

1. **Check the route first:** Look in `moduleRegistry.ts` to make sure you're working in the active module.
2. **Use `tenant_id`:** Don't add new `parent_tenant_id` or company-hierarchy references.
3. **Use the money kernel:** For anything touching bills, payments, or cashbook, target `bills_pays` + `money_kernel_v2` (`rpc_*` via `moneyKernelRepository.ts`, which uses `supabase as any` for untyped RPCs).
4. **Verify currency context:** Explicitly track whether a field is in **books currency (BDT)**, **purchase currency**, or **settlement currency**.
