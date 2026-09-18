# Business models (as-built)

TradeFlow BD is **one platform, several ways to sell**. A company (parent tenant) turns modules on via `tenant_modules`. Do not mix stock tables across models.

People say **BW**, **pre-order**, **K-beauty**, **thrift**. In code those are the rows below.

---

## Models

| Name people use | Code / modules | What it sells | Stock | Money |
| :--- | :--- | :--- | :--- | :--- |
| **BW** (Brandwala wholesale) | `procurement_stock`, `products`, `sales_invoice`, `shop_order` (stock-backed shop), `customer`, `wallet`, `reporting_treasury`, `after_sales` | In-hand goods to B2B buyers, walk-in, dropship resellers | Parent `global_stocks`. Children see **allocations** only. Shop sells from `global_stock_allocations`. | Company invoices (`global_invoices`). Ledger via `record_ledger_transaction`. |
| **Pre-order** | `product_based_costing`, `costingFile`, shop catalog negotiation, `procurement_demand` | Quotes **before** goods land | No warehouse row yet. Demand list → later inbound shipment | PBC file → customer confirm → same demand desk as catalog preorders |
| **K-beauty** | `koba` (`koba_retail`, `koba_wholesale`) | UK/K-beauty catalog, staff cart + shop cart | **Own** tables: `koba_products`, `koba_orders`, `koba_carts`. Not `global_stocks`. | Commission / profit share in `koba_retail_settings`. Not the wholesale FIFO desk. |
| **Thrift** | `thrift` (+ submodules) | One-off garments, POS, courier COD | **Own** thrift boxes/items. Not on the global entity model. | Thrift POS + reports. Do not copy this folder into BW modules. |

Dropship is a **channel of BW**, not a fourth company type. Investor portal is read-only capital, not a sales model.

---

## How they relate

```text
Pre-order (PBC / catalog quote)
        ↓ demand + inbound shipment
BW warehouse (global_stocks) → wholesale invoice / stock-backed shop / dropship

K-beauty (koba_*)     ← separate catalog & orders
Thrift (thrift_*)     ← separate intake & POS
```

Shared: tenants, grants, FX catalogs. Wallet when that model posts the ledger. Invoices for BW: company `global_invoices` + `issued_by_tenant_id`. No shadow P&L tables — margins from operational snapshots (`unit_cost_price`, landed cost until `costs_locked`).

---

## Do not

- Sell K-beauty or thrift SKUs from `global_stock_allocations`.
- Put thrift garments on `global_stocks`.
- Treat a PBC line as on-hand stock until it is received on a shipment.
- Enable every module on every tenant. BW vs K-beauty vs thrift is a **module set**, not a different app binary.

---

## Where to code

| Model | Spec | UI |
| :--- | :--- | :--- |
| BW | [procurement](../features/procurement_stock/01-prd.md), [sales invoice](../features/sales_invoice/01-prd.md), [shop order](../features/shop_order/01-prd.md) | `web/src/modules/procurement_stock/`, `sales_invoice/`, `shop_order/` |
| Pre-order | [PBC](../features/product_based_costing/01-prd.md), shop negotiation in [shop_order](../features/shop_order/01-prd.md) | `product_based_costing/`, `costingFile/`, `shop_order/` |
| K-beauty | [global_reference PRD § Koba](../features/global_reference/01-prd.md) | `web/src/modules/koba/` |
| Thrift | [thrift](../features/thrift/01-prd.md) | `web/src/modules/thrift/` |
