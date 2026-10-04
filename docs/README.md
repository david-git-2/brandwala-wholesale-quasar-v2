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

- BW stock: parent `global_stocks`. **Retire** child-quota `global_stock_allocations` (no sister stock UI). Shop/invoice still have live FKs until [PS9](features/procurement_stock/00-gaps.md). Target shop sell = listings on `global_stock_id`.
- Pre-order is demand until received on a shipment.
- K-beauty = `koba_*`. Thrift = `thrift_*`. Never mix into `global_stocks`.
- Scopes: `platform` \| `app` \| `shop` \| `investor`. Grants: `effectiveGrants` + `has_module_action()`.
- **Bills & pays** is one pack ([bills_pays spec](features/bills_pays/spec.md)). **Profile** = party. **Bill** = issued paper (take / condition / dropship merchant; AP later). Paper status `draft` / `issued` / `voided`; money `due` / `partially_paid` / `paid`. **Proforma** = Delivery maybe-paper, not a bill status. **Pay** = cash in or out. **Alloc** = pay → open bill only. **Cashbook** = leftover we owe them (and tenant/courier cash). No wallet product. Live table rename map in [spec](features/bills_pays/spec.md). Code folders `sales_invoice/` + `wallet/` are desks. No fake `wallet_posted`.
- Invoices (AR): company-owned `global_invoices`; `issued_by_tenant_id` is the desk.
- Wholesale **pack-out** is the **Delivery paper** desk (nav label; code `procurement_fulfill`). Optional **proforma** is not an issued bill. Stock on the paper is `held`. Close each packed qty with a dropdown: **take** (accepted) → take bill + `sale_outbound`; **condition** → condition bill, stock stays `held`; **return** → sellable, no bill. **Bills trade compose** can also issue take or condition (one kind per bill). Walk-in compose is take only. Dropship bill-at-ship unchanged.
- Inbound **vendor better price** is on **outcome** rows. Lots FK `outcome_id`. Cargo never reduces. After a **delivery return** (e.g. short-dated): return inbound first, then restamp **on-hand** lots from outcomes — not a hand stock edit; do not rewrite qty still out. Same SKU other lots unchanged. Not a customer pay. Vendor/cargo **AP bill + pay out** later ([WA15](features/bills_pays/00-gaps.md)).
- Money: **one pay-in path** (cash, bank, store credit, courier remittance). COD face stays on the order until remittance. Do not add a second payments product per channel.
- Investor portal v1 read-only.
- Copy the **module’s** Pinia or Vue Query pattern. Do not convert it.

---

## Commands

| Task | Command |
| :--- | :--- |
| Web | `pnpm --dir web dev` |
| Types/lint | `pnpm --dir web type-check` / `lint` |
| SQL on existing local DB | `pnpm run backend:local` |
| Schema split check | `pnpm run backend:schema:diff` |
