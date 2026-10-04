# Login surfaces and feature scope

Four **login scopes** (not job titles). Theme: `theme-platform` | `theme-app` | `theme-shop` | `theme-investor`.

| Scope | URL | Who | Does |
| :--- | :--- | :--- | :--- |
| `platform` | `/auth/platform/login` → `/platform/*` | Superadmin | Tenants, modules catalog, global reference |
| `app` | `/:slug/app/*` | Tenant staff | ERP. Grants via `effectiveGrants` |
| `shop` | `/:slug/shop/*` or custom host | Buyer / reseller | Storefront, cart, own orders, Koba retail cart |
| `investor` | `/:slug/investor/*` | Capital partner | **Read-only** statements. No withdraw |

Nav modules in code use `app` | `shop` only (`moduleRegistry`). Platform and investor are separate route trees.

---

## Feature × surface (as-built)

| Feature pack | platform | app | shop | investor |
| :--- | :---: | :---: | :---: | :---: |
| tenant_auth / membership | yes | yes | login | login |
| global_reference | yes (catalogs) | read | — | — |
| Koba | — | wholesale + staff cart | retail cart | — |
| procurement_stock / vendor | — | yes | — | — |
| products / tags | — | yes | browse via shop | — |
| product_based_costing | — | yes | — | — |
| bills_pays | — | bills + payments + cashbook | merchant statement | — |
| after_sales | — | yes | complaints via shop order | — |
| shop_order | — | config, dropship, pricing | catalog, cart, orders | — |
| customer | — | hub (groups + recipients) | group members | — |
| reporting_treasury | — | yes | — | — |
| notifications / tasks | — | yes | optional inbox | — |
| dashboard | yes (platform home) | staff home | customer home | — |
| investor_capital | — | staff capital | — | portal |
| thrift | — | yes | — | — |

**Out of all shop/investor:** warehouse bins, landed-cost lock, schema split, platform tenant provision.

Module **in/out** detail lives on that pack’s `spec.md` → Scope. Tables, RPCs, and button wiring: grep `supabase/schemas/` and `web/src/modules/<name>/`. **Bills & pays:** `docs/features/bills_pays/spec.md`. App code: `sales_invoice/` + `wallet/`.
