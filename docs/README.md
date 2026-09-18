# TradeFlow BD — docs index

Load **this file first**. Then **one** module `01-prd.md`. Then code. See [STRUCTURE.md](STRUCTURE.md).

Missing fact → `DOC_GAP` (`.cursor/rules/docs-first.mdc`). Do not guess.

Live SQL: `supabase/schemas/`. Types: `web/src/types/database.types.ts`.

---

## I want to know

| Question | Open |
| :--- | :--- |
| Who logs in where, which features? | [scopes](architecture/scopes.md) |
| How this company sells (BW, pre-order, K-beauty, thrift) | [business-models](architecture/business-models.md) |
| What is unfinished / wrong in a module? | That module’s `00-gaps.md` |
| Where is the code / SQL? | [Module map](#module-map) |
| Tables / RPCs / button wiring | Same folder `02` `03` `05` |
| Login / grants | [tenant_auth](features/tenant_auth/01-prd.md) |
| List page look | [ui-standards](guides/ui-standards.md) |
| Pinia vs Vue Query / toasts | [state](architecture/state.md) |
| Change the database | [database](architecture/database.md) + [split tracker](../doc/supabase-schema.md) |
| Add a new doc / module | [STRUCTURE](STRUCTURE.md) |

---

## Module map

UI under `web/src/modules/` unless noted. Agent: `01-prd.md` + `00-gaps.md`. Same folder `02`–`05` when you need to **understand** tables, RPCs, or screens. Surfaces: [scopes](architecture/scopes.md).

| Module | Spec | Gaps | UI | SQL |
| :--- | :--- | :--- | :--- | :--- |
| Tenant / auth | [01](features/tenant_auth/01-prd.md) | [gaps](features/tenant_auth/00-gaps.md) | `auth/`, `tenant/`, `membership/`, `access_control/` | stubs + `public.sql` |
| Global reference | [01](features/global_reference/01-prd.md) | [gaps](features/global_reference/00-gaps.md) | `global_reference/`, `global/`, `tag/` | `public.sql` |
| K-beauty (Koba) | same PRD | same gaps | `koba/` | `koba_*` in `public.sql` |
| Procurement | [01](features/procurement_stock/01-prd.md) | [gaps](features/procurement_stock/00-gaps.md) | `procurement_stock/`, `vendor/` | **split** `procurement/` |
| Products | [01](features/products/01-prd.md) | [gaps](features/products/00-gaps.md) | `products/` | `public.sql` |
| Pre-order (PBC) | [01](features/product_based_costing/01-prd.md) | [gaps](features/product_based_costing/00-gaps.md) | `product_based_costing/`, `costingFile/` | `public.sql` |
| Sales invoices | [01](features/sales_invoice/01-prd.md) | [gaps](features/sales_invoice/00-gaps.md) | `sales_invoice/`, `invoice_shared/` | **split** `sales_invoice/` |
| After-sales | [01](features/after_sales/01-prd.md) | [gaps](features/after_sales/00-gaps.md) | `after_sales/` | invoice + shop_order RPCs |
| Shop / dropship | [01](features/shop_order/01-prd.md) | [gaps](features/shop_order/00-gaps.md) | `shop_order/` | **split** `shop_order/` |
| Customer | [01](features/customer/01-prd.md) | [gaps](features/customer/00-gaps.md) | `customer/` | `public.sql` |
| Wallet | [01](features/wallet/01-prd.md) | [gaps](features/wallet/00-gaps.md) | `wallet/` | stub; live `public.sql` |
| Reporting | [01](features/reporting_treasury/01-prd.md) | [gaps](features/reporting_treasury/00-gaps.md) | `reporting_treasury/` | `public.sql` |
| Notifications | [01](features/notifications/01-prd.md) | [gaps](features/notifications/00-gaps.md) | `notifications/`, `tasks/` | **split** `notifications/` |
| Dashboard | [01](features/dashboard/01-prd.md) | [gaps](features/dashboard/00-gaps.md) | `dashboard/` | n/a |
| Investor | [01](features/investor_capital/01-prd.md) | [gaps](features/investor_capital/00-gaps.md) | `investor_capital/`, `investor_portal/` | stub |
| Thrift | [01](features/thrift/01-prd.md) | [gaps](features/thrift/00-gaps.md) | `thrift/` | stub; live `public.sql` |

Also in code, no pack: `settings/`, `navigation/`, `featureCatalog/`.

---

## Locked (do not reinvent)

- BW stock: parent `global_stocks`; children = allocations; shop sells `global_stock_allocations`.
- Pre-order is demand until received on a shipment.
- K-beauty = `koba_*`. Thrift = `thrift_*`. Never mix into `global_stocks`.
- Scopes: `platform` \| `app` \| `shop` \| `investor`. Grants: `effectiveGrants` + `has_module_action()`.
- Invoices: company-owned `global_invoices`; `issued_by_tenant_id` is the desk.
- Ledger: only `record_ledger_transaction`. No fake `wallet_posted`.
- Investor portal v1 read-only.
- Copy the **module’s** Pinia or Vue Query pattern. Do not convert it.

---

## Commands

| Task | Command |
| :--- | :--- |
| Web | `pnpm --dir web dev` |
| Types/lint | `pnpm --dir web type-check` / `lint` |
| SQL on existing local DB | `pnpm run backend:local` then `backend:types:local` |
| Schema split check | `pnpm run backend:schema:diff` |
