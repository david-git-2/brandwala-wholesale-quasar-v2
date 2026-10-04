# TradeFlow BD — docs index

Load **this file first**. Then that module’s `spec.md` + `00-gaps.md`. Money → [bills_pays spec](features/bills_pays/spec.md) + [money-story](features/bills_pays/money-story.md). Then code. See [STRUCTURE.md](STRUCTURE.md).

Missing fact → `DOC_GAP` (`.cursor/rules/docs-first.mdc`). Do not guess.

Live SQL: `supabase/schemas/`. Types: `web/src/types/database.types.ts`.

---

## I want to know

| Question | Open |
| :--- | :--- |
| Who logs in where, which features? | [scopes](architecture/scopes.md) |
| How this company sells (BW, pre-order, K-beauty, thrift) | [business-models](architecture/business-models.md) |
| Wholesale vs dropship bill → pay (numbers) | [money-story](features/bills_pays/money-story.md) |
| Bills vs pays vs cashbook | [bills_pays spec](features/bills_pays/spec.md) |
| What numbers go on reports (sales vs cash vs COD) | [reporting spec](features/reporting_treasury/spec.md) |
| What is unfinished / wrong in a module? | That module’s `00-gaps.md` |
| Where is the code / SQL? | [Module map](#module-map) |
| Tables / RPCs / button wiring | `supabase/schemas/` + module code |
| Login / grants | [tenant_auth spec](features/tenant_auth/spec.md) |
| List page look | [ui-standards](guides/ui-standards.md) |
| Pinia vs Vue Query / toasts | [state](architecture/state.md) |
| Change the database | [database](architecture/database.md) + [split tracker](../doc/supabase-schema.md) |
| Add a new doc / module | [STRUCTURE](STRUCTURE.md) |

---

## Module map

UI under `web/src/modules/` unless noted. Agent: `spec.md` + `00-gaps.md`. Surfaces: [scopes](architecture/scopes.md).

| Module | Spec | Gaps | UI | SQL |
| :--- | :--- | :--- | :--- | :--- |
| Tenant / auth | [spec](features/tenant_auth/spec.md) | [gaps](features/tenant_auth/00-gaps.md) | `auth/`, `tenant/`, `membership/`, `access_control/` | `public.sql` |
| Global reference | [spec](features/global_reference/spec.md) | [gaps](features/global_reference/00-gaps.md) | `global_reference/`, `global/`, `tag/` | `public.sql` |
| K-beauty (Koba) | same spec | same gaps | `koba/` | `koba_*` in `public.sql` |
| Procurement | [spec](features/procurement_stock/spec.md) | [gaps](features/procurement_stock/00-gaps.md) | `procurement_stock/`, `vendor/` | **split** `procurement/` |
| Products | [spec](features/products/spec.md) | [gaps](features/products/00-gaps.md) | `products/` | `public.sql` |
| Pre-order (PBC) | [spec](features/product_based_costing/spec.md) | [gaps](features/product_based_costing/00-gaps.md) | `product_based_costing/`, `costingFile/` | `public.sql` |
| **Bills & pays** | [spec](features/bills_pays/spec.md) | [gaps](features/bills_pays/00-gaps.md) | desks: `sales_invoice/`, `wallet/` (code names) | invoice split; pays in `public.sql` |
| After-sales | [spec](features/after_sales/spec.md) | [gaps](features/after_sales/00-gaps.md) | `after_sales/` | invoice + shop_order RPCs |
| Shop / dropship | [spec](features/shop_order/spec.md) | [gaps](features/shop_order/00-gaps.md) | `shop_order/` | **split** `shop_order/` |
| Customer | [spec](features/customer/spec.md) | [gaps](features/customer/00-gaps.md) | `customer/` | `public.sql` |
| Reporting | [spec](features/reporting_treasury/spec.md) | [gaps](features/reporting_treasury/00-gaps.md) | `reporting_treasury/` | `public.sql` |
| Notifications | [spec](features/notifications/spec.md) | [gaps](features/notifications/00-gaps.md) | `notifications/`, `tasks/` | **split** `notifications/` |
| Dashboard | [spec](features/dashboard/spec.md) | [gaps](features/dashboard/00-gaps.md) | `dashboard/` | n/a |
| Investor | [spec](features/investor_capital/spec.md) | [gaps](features/investor_capital/00-gaps.md) | `investor_capital/`, `investor_portal/` | stub |
| Thrift | [spec](features/thrift/spec.md) | [gaps](features/thrift/00-gaps.md) | `thrift/` | stub; live `public.sql` |

Also in code, no pack: `settings/`, `navigation/`, `featureCatalog/`.

---

## Locked (do not reinvent)

Detail lives in the linked spec — do not duplicate here.

| Topic | Open |
| :--- | :--- |
| Login surfaces | [scopes](architecture/scopes.md) |
| BW / pre-order / Koba / thrift | [business-models](architecture/business-models.md) |
| Stock, receive, Delivery paper | [procurement spec](features/procurement_stock/spec.md) |
| Bills, pays, cashbook, money layers | [bills_pays spec](features/bills_pays/spec.md) |
| Shop / dropship channel | [shop_order spec](features/shop_order/spec.md) |
| Investor portal v1 read-only | [investor_capital spec](features/investor_capital/spec.md) |
| UI pattern in a module | Copy that module’s Pinia or Vue Query — do not convert |

---

## Commands

| Task | Command |
| :--- | :--- |
| Web | `pnpm --dir web dev` |
| Types/lint | `pnpm --dir web type-check` / `lint` |
| SQL on existing local DB | `pnpm run backend:local` |
| Schema split check | `pnpm run backend:schema:diff` |
