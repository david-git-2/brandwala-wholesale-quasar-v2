# TradeFlow BD — docs index

**Agents:** skip this file unless the user names it. Truth = code + `supabase/schemas/`. UI = `.cursor/rules/quasar-ui.mdc`.

**Money (humans):** [bridge § Atlas](features/money_bill_bridge/spec.md#atlas) · [money](features/money/spec.md) · [bills](features/bills/spec.md) · [bridge](features/money_bill_bridge/spec.md). Tests: [tests.md](features/bills_pays/tests.md).

Live SQL: `supabase/schemas/`. Types: `web/src/types/database.types.ts`. See [STRUCTURE.md](STRUCTURE.md).

---

## I want to know

| Question | Open |
| :--- | :--- |
| Who logs in where? | [scopes](architecture/scopes.md) |
| BW / pre-order / Koba / thrift | [business-models](architecture/business-models.md) |
| Money atlas | [bridge § Atlas](features/money_bill_bridge/spec.md#atlas) |
| Stock spine | [stock-spine](features/procurement_stock/stock-spine.md) |
| Shipment rate / BDT cost | [shipment-rate-calculations](features/procurement_stock/shipment-rate-calculations.md) |
| Reporting numbers | [reporting spec](features/reporting_treasury/spec.md) |
| Roadmap / backlog | [ROADMAP.md](ROADMAP.md) · [BACKLOG.md](BACKLOG.md) |
| List page chrome | [quasar-ui](../.cursor/rules/quasar-ui.mdc) · [OpsListPage.skeleton.vue](guides/OpsListPage.skeleton.vue) |
| Deploy Cloudflare | [cloudflare-pages-deploy](guides/cloudflare-pages-deploy.md) |
| State / Pinia vs Query | [state](architecture/state.md) |
| DB change | [database](architecture/database.md) |
| Tenant id cutover (prod only) | [tenant-id-cutover](architecture/tenant-id-cutover.md) |
| Add a doc | [STRUCTURE](STRUCTURE.md) |

---

## Module map

| Module | Spec | UI | SQL |
| :--- | :--- | :--- | :--- |
| Tenant / auth | [spec](features/tenant_auth/spec.md) | `auth/`, `tenant/`, `membership/`, `access_control/` | `public.sql` |
| Global reference | [spec](features/global_reference/spec.md) | `global_reference/`, `global/`, `tag/` | `public.sql` |
| K-beauty (Koba) | same | `koba/` | `koba_*` |
| Procurement | [spec](features/procurement_stock/spec.md) | `procurement_stock/`, `vendor/` | `procurement/` |
| Products | [spec](features/products/spec.md) | `products/` | `public.sql` |
| Pre-order (PBC) | [spec](features/product_based_costing/spec.md) | `product_based_costing/` | `public.sql` |
| Money | [spec](features/money/spec.md) | `wallet/` | `money_kernel_v2/` |
| Bills | [spec](features/bills/spec.md) | `sales_invoice/`, AP desks | `money_kernel_v2/` |
| Money↔bill | [spec](features/money_bill_bridge/spec.md) | pay dialogs | `money_kernel_v2/` |
| Bills & pays desks | [atlas](features/money_bill_bridge/spec.md#atlas) | `bills_pays/` | same |
| After-sales | [spec](features/after_sales/spec.md) | `after_sales/` | invoice + shop_order |
| Shop / dropship | [spec](features/shop_order/spec.md) | `shop_order/` | `shop_order/` |
| Customer | [spec](features/customer/spec.md) | `customer/` | `public.sql` |
| Reporting | [spec](features/reporting_treasury/spec.md) | `reporting_treasury/` | `public.sql` |
| Notifications | [spec](features/notifications/spec.md) | `notifications/`, `tasks/` | `notifications/` |
| Dashboard | [spec](features/dashboard/spec.md) | `dashboard/` | `get_app_dashboard_bundle` |
| Investor | [spec](features/investor_capital/spec.md) | `investor_capital/`, `investor_portal/` | stub |
| Thrift | [spec](features/thrift/spec.md) | `thrift/` | `public.sql` |
| Landing / help | [spec](features/landing/spec.md) | `landing/`, `help/` | n/a |

---

## Commands

| Task | Command |
| :--- | :--- |
| Web | `pnpm --dir web dev` |
| Types/lint | `pnpm --dir web type-check` / `lint` |
| Local migrations | `pnpm run backend:local` |
