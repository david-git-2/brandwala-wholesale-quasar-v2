# Login surfaces and feature scope

Five **login scopes** (not job titles). Theme: `theme-platform` | `theme-app` | `theme-shop` | `theme-investor` | `theme-proxy`.

| Scope | URL | Who | Does |
| :--- | :--- | :--- | :--- |
| `platform` | `/auth/platform/login` → `/platform/*` | Superadmin | Tenants, modules catalog, global reference |
| `app` | `/:slug/app/*` | Tenant staff | ERP. Grants via `effectiveGrants` |
| `shop` | `/:slug/shop/*` or custom host | Buyer / reseller | Storefront, cart, own orders, Koba retail cart |
| `investor` | `/:slug/investor/*` | Capital partner | **Read-only** statements. No withdraw |
| `proxy` | `/:slug/proxy/*` | Proxy customer / supplier member | Purchase requests, supplier place queues — [proxy purchase spec](../features/proxy_purchase/spec.md) |

Nav modules in code use `app` | `shop` only (`moduleRegistry`). Platform, investor, and proxy are separate route trees.

---

## Feature × surface (as-built)

| Feature pack | platform | app | shop | investor | proxy |
| :--- | :---: | :---: | :---: | :---: | :---: |
| tenant_auth / membership | yes | yes | login | login | login |
| global_reference | yes (catalogs) | read | — | — | — |
| Koba | — | wholesale + staff cart | retail cart | — | — |
| procurement_stock / vendor | — | yes | — | — | — |
| products / tags | — | yes | browse via shop | — | — |
| product_based_costing | — | yes | — | — | — |
| bills_pays | — | bills + payments + cashbook | merchant statement | — | — |
| after_sales | — | yes | complaints via shop order | — | — |
| shop_order | — | config, dropship, pricing | catalog, cart, orders | — | — |
| customer | — | hub (groups + recipients) | group members | — | — |
| reporting_treasury | — | yes | — | — | — |
| notifications / tasks | — | yes | optional inbox | — | — |
| dashboard | yes (platform home) | staff home | customer home | — | — |
| investor_capital | — | staff capital | — | portal | — |
| thrift | — | yes | — | — | — |
| proxy_purchase | — | ops + people admin | — | — | customer + supplier portal |

**Out of all shop/investor/proxy:** warehouse bins, landed-cost lock, schema split, platform tenant provision.

Module **in/out** detail lives on that pack’s `spec.md` → Scope. Tables, RPCs, and button wiring: grep `supabase/schemas/` and `web/src/modules/<name>/`. **Money system:** `docs/features/money_bill_bridge/spec.md#atlas`. App code: `sales_invoice/` + `wallet/`.
