# TradeFlow BD — docs index

Load **this file first** for product work. **Money system:** [bridge spec § Atlas](features/money_bill_bridge/spec.md#atlas) · [money](features/money/spec.md) · [bills](features/bills/spec.md) · [bridge](features/money_bill_bridge/spec.md). Tests: [tests.md](features/bills_pays/tests.md) → `supabase/tests/`. Other modules: `spec.md`. Then code. See [STRUCTURE.md](STRUCTURE.md).

Unclear fact → ask one question. Prefer code + `spec.md`; do not invent statuses/RPCs.

Live SQL: `supabase/schemas/`. Types: `web/src/types/database.types.ts`.

---

## I want to know

| Question | Open |
| :--- | :--- |
| Daily staff workflows (operating manual) | App `/operating-manual` only (`web/src/modules/operating_manual/`) |
| Product scenario catalogs (what to cover / build) | [product-scenarios README](product-scenarios/README.md) |
| Dropship lifecycle (COD, failed delivery, returns) | [dropship-lifecycle-guide](product-scenarios/dropship-lifecycle-guide.md) |
| Platform guide (kernels, modules) | App `/docs` |
| Who logs in where, which features? | [scopes](architecture/scopes.md) |
| How this company sells (BW, pre-order, K-beauty, thrift) | [business-models](architecture/business-models.md) |
| Pre-order flow (target ops story — load only for that task) | [preorder-fulfillment-flow](preorder-fulfillment-flow.md) |
| **Money system — atlas** | [bridge spec § Atlas](features/money_bill_bridge/spec.md#atlas) |
| Cash / lots / treasury | [money](features/money/spec.md) |
| Bills / AP / AR paper | [bills](features/bills/spec.md) |
| Pay ↔ bill settle | [bridge](features/money_bill_bridge/spec.md) |
| Document numbering | [architecture/document-numbering](architecture/document-numbering.md) |
| Warehouse stock movements (spine) | [stock-spine](features/procurement_stock/stock-spine.md) |
| Shipment rate + product BDT cost calculations | [shipment-rate-calculations](features/procurement_stock/shipment-rate-calculations.md) |
| What numbers go on reports (sales vs cash vs COD) | [reporting spec](features/reporting_treasury/spec.md) |
| Product roadmap (Now / Next / Later) | [ROADMAP.md](ROADMAP.md) · feature IDs in [BACKLOG.md](BACKLOG.md) |
| Catalog scrape/upload log & app versions (planned) | [products refresh & release](features/products/upload-and-release-visibility.md) |
| Prod Disk IO Budget warning (25 Oct 2026) | [fix note](../doc/fix/2026-10-25-prod-disk-io-budget.md) |
| Where is the code / SQL? | [Module map](#module-map) |
| Tables / RPCs / button wiring | `supabase/schemas/` + module code |
| Login / grants | [tenant_auth spec](features/tenant_auth/spec.md) |
| Collapse `parent_tenant_id` into `tenant_id` (prod phase 11 only) | [tenant-id-cutover](architecture/tenant-id-cutover.md) — do not load unless running that cutover |
| List page look | [quasar-ui rule](../.cursor/rules/quasar-ui.mdc) · [OpsListPage.skeleton.vue](guides/OpsListPage.skeleton.vue) · [ui-standards](guides/ui-standards.md) (grep only) |
| Deploy web to Cloudflare Pages (`frontend:prod`) | [cloudflare-pages-deploy](guides/cloudflare-pages-deploy.md) |
| Pinia vs Vue Query / toasts | [state](architecture/state.md) |
| Change the database | [database](architecture/database.md) + [split tracker](../doc/supabase-schema.md) |
| Add a new doc / module | [STRUCTURE](STRUCTURE.md) |

---

## Module map

UI under `web/src/modules/` unless noted. Agent: module `spec.md`. Surfaces: [scopes](architecture/scopes.md).

| Module | Spec | UI | SQL |
| :--- | :--- | :--- | :--- |
| Tenant / auth | [spec](features/tenant_auth/spec.md) | `auth/`, `tenant/`, `membership/`, `access_control/` | `public.sql` |
| Global reference | [spec](features/global_reference/spec.md) | `global_reference/`, `global/`, `tag/` | `public.sql` |
| K-beauty (Koba) | same spec | `koba/` | `koba_*` in `public.sql` |
| Procurement | [spec](features/procurement_stock/spec.md) | `procurement_stock/`, `vendor/` | **split** `procurement/` |
| Products | [spec](features/products/spec.md) | `products/` | `public.sql` |
| Pre-order (PBC) | [spec](features/product_based_costing/spec.md) | `product_based_costing/`, `costingFile/` | `public.sql` |
| **Money** (cash) | [spec](features/money/spec.md) | `wallet/` | `supabase/schemas/money_kernel_v2/` |
| **Bills** (paper) | [spec](features/bills/spec.md) | `sales_invoice/`, AP desks | `supabase/schemas/money_kernel_v2/` |
| **Money↔bill bridge** | [spec](features/money_bill_bridge/spec.md) | pay dialogs | `supabase/schemas/money_kernel_v2/` |
| **Bills & pays (desks)** | [atlas](features/money_bill_bridge/spec.md#atlas) | `sales_invoice/`, `wallet/`, `bills_pays/` | same |
| After-sales | [spec](features/after_sales/spec.md) | `after_sales/` | invoice + shop_order RPCs |
| Shop / dropship | [spec](features/shop_order/spec.md) | `shop_order/` | **split** `shop_order/` |
| Customer | [spec](features/customer/spec.md) | `customer/` | `public.sql` |
| Reporting | [spec](features/reporting_treasury/spec.md) | `reporting_treasury/` | `public.sql` |
| Notifications | [spec](features/notifications/spec.md) | `notifications/`, `tasks/` | **split** `notifications/` |
| Dashboard (app = Today’s plan) | [spec](features/dashboard/spec.md) | `dashboard/` | `get_app_dashboard_bundle` |
| Investor | [spec](features/investor_capital/spec.md) | `investor_capital/`, `investor_portal/` | stub |
| Thrift | [spec](features/thrift/spec.md) | `thrift/` | stub; live `public.sql` |
| Landing / help (public) | [spec](features/landing/spec.md) | `landing/`, `help/` | n/a |

Also in code, no pack: `settings/`, `navigation/`, `featureCatalog/`.

---

## Locked (do not reinvent)

Detail lives in the linked spec — do not duplicate here.

| Topic | Open |
| :--- | :--- |
| Login surfaces | [scopes](architecture/scopes.md) |
| BW / pre-order / Koba / thrift | [business-models](architecture/business-models.md) |
| Stock, receive, Delivery paper | [procurement spec](features/procurement_stock/spec.md) · [stock spine](features/procurement_stock/stock-spine.md) |
| Bills, pays, cashbook, money layers | [bridge spec § Atlas](features/money_bill_bridge/spec.md#atlas) |
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
| Schema change / split check | `pnpm run backend:schema:sync -- <name>` |
