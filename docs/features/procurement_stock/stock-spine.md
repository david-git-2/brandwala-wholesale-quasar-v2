# Stock spine — warehouse quantity & movements

## As-built

| | |
| :--- | :--- |
| Purpose | **Single contract** for changing BW `global_stocks` quantity, location, availability, and grade |
| Truth | `global_stocks` · `stock_movements` · `stock_movement_lines` |
| Primary writer | `create_and_post_stock_movement` — grep `supabase/_domain_splits_archive/procurement/03_rpcs.sql` |
| Inbound lots | `post_shipment_outcome_stock` → internal `_stock_spine_*` (same tables; does **not** call `post_stock_movement`) |
| Sales deduct | `commit_sales_bill_stock` on bill issue |
| Product scope | **BW** parent-tenant warehouse only — not Koba/thrift ([business-models](../architecture/business-models.md)) |
| Procurement UX | [spec](spec.md) · inbound money → spec **Inbound ↔ money** |

## Scope

| In | Out |
| :--- | :--- |
| Tier 1 & 2 warehouse actions → RPC map (below) | Money spine — bills/pays only |
| Planning vs posted, movement types | Shop `shop_customer_stocks` |
| Cycle count, bill stock commit | Full ATP / promise engine |
| `preorder_demand` vendor buy (no qty change) | **Retired:** delivery paper dispatch/outcome RPCs |

---

## Layering

```text
Feature UI / close RPCs (demand buy, returns, warehouse, bill issue)
        │
        ▼  must end in a spine writer (below)
Stock spine
        │
        ▼
global_stocks (+ movement audit rows)
```

| Layer | Owns | Changes qty? |
| :--- | :--- | :--- |
| **Planning** | `shop_order_item_stock_picks` (dropship), demand vendor placements | **No** |
| **Spine** | Movement RPCs below | **Yes** |
| **Read** | `searchStockNetwork`, `list_global_stocks_groups`, `list_stock_movements` | No |

**Rule:** Do not `UPDATE global_stocks.quantity` from new feature RPCs except inside spine functions. Prefer `p_reference_type` / `p_reference_id` on movements.

---

## Movement types (`stock_movement_type`)

| Type | Effect on qty | Typical use |
| :--- | :--- | :--- |
| `receive_putaway` | Inbound / transfer grain | Header from `post_shipment_outcome_stock` |
| `location_transfer` | Move between bins (split/merge lots) | Warehouse move dialog |
| `availability_transfer` | Hold ↔ sellable ↔ unsellable | Grade / availability dialog |
| `grade_change` | Reclassify grade tag | Grade dialog |
| `adjustment` | +/- correction | Movement desk; cycle count approve |
| `issue_outbound` | Deduct only | Bill commit, manual outbound |
| `return_inbound` | Add or customer return path | Returns kernel |
| `vendor_return` | Deduct (RTV) | `return_shipment_to_vendor` |
| `receive_rollback` | Deduct | Reserved; no public RPC yet |

Posted logic: `post_stock_movement`. One-shot: `create_and_post_stock_movement`. Multi-line desk: `create_stock_movement` → `add_stock_movement_line` → `post_stock_movement`.

---

## Spine writers

| Writer | Role | Typical `reference_type` |
| :--- | :--- | :--- |
| **`create_and_post_stock_movement`** | One-shot movement | `global_stock`, `preorder_demand`, … |
| **`post_shipment_outcome_stock`** | Inbound lots + `receive_putaway` audit | shipment id |
| **`commit_sales_bill_stock`** | Bill issue deduct | `sales_invoice` |
| **`approve_stock_physical_count`** | Variance → `adjustment` movement | `stock_physical_count` |
| **`return_shipment_to_vendor`** | RTV deduct | `shipment_return` |
| **Movement desk** | Draft multi-line | user-entered |

Returns: `10_returns_kernel.sql` · dropship finalize.

---

## Tier 1 — warehouse actions

| Action | Posted? | Primary RPC(s) | `movement_type` | UI |
| :--- | :--- | :--- | :--- | :--- |
| Receive vs shipment | Yes | `post_shipment_outcome_stock` | `receive_putaway` | Shipment → Post to stock |
| Lot / expiry on receipt | Yes (lots) | `post_shipment_outcome_stock` · batch `paste_batch_code_items` | — | Shipment extras / batch |
| Putaway / relocate | Yes | `create_and_post_stock_movement` | `location_transfer` | Move location dialog |
| Hold / release | Yes | `create_and_post_stock_movement` | `availability_transfer` | Grade / availability |
| Reclassify (grade) | Yes | `create_and_post_stock_movement` | `grade_change` | Move grade dialog |
| Adjust (damage / shrink) | Yes | Movement desk or `create_and_post_stock_movement` | `adjustment` | Stock movements page |
| Wholesale sale stock-out | Yes | `post_sales_invoice` → `commit_sales_bill_stock` | `issue_outbound` | Bills desk issue |
| Customer return + disposition | Yes | `process_wholesale_invoice_return` | `return_inbound` · `grade_change` | Returns |

Counter sales and wholesale invoices deduct on **`commit_sales_bill_stock`** at issue (no separate dispatch paper).

---

## Tier 2 — warehouse actions

| Action | Posted? | Primary RPC(s) | Notes |
| :--- | :--- | :--- | :--- |
| Inbound inspect / QC | Yes (unsellable lots) | `post_shipment_outcome_stock` | Extras `kind=unsellable`, reasons `damaged` / `missing` |
| Cycle count | Yes on approve | `create_stock_physical_count` … `approve_stock_physical_count` | Approve posts `adjustment` |
| RTV outbound | Yes | `return_shipment_to_vendor` | `vendor_return` movement |
| Refund linkage | Money | `process_wholesale_invoice_return` | [Money kernel](README.md) |

---

## RPC index (stock spine)

| RPC | Args (summary) | Idempotency |
| :--- | :--- | :--- |
| `post_shipment_outcome_stock` | `p_shipment_id`, `p_stock_rows?` | Incremental post |
| `create_and_post_stock_movement` | tenant, stock, qty, to_* , type, notes, reference | New movement each call |
| `create_stock_movement` / `add_stock_movement_line` / `post_stock_movement` | desk draft | Post once per movement id |
| `create_stock_physical_count` | tenant, location?, notes | New session |
| `approve_stock_physical_count` | count id | → posted; one adjustment movement |
| `return_shipment_to_vendor` | shipment, items json, outcome | Financial side + RTV movement |
| `commit_sales_bill_stock` | bill id | Bill issue deduct |
| `close_preorder_demand_document` | doc type/id, action | Demand close; return picks → spine when applicable |

---

## Feature → spine map (quick)

| User action | RPC | Hits spine? |
| :--- | :--- | :--- |
| Issue wholesale bill | `commit_sales_bill_stock` | Yes |
| Post to stock | `post_shipment_outcome_stock` | Yes |
| Shelf / grade / avail | `create_and_post_stock_movement` | Yes |
| Cycle count approve | `approve_stock_physical_count` | Yes |

---

## Web entry points

| Path | RPC |
| :--- | :--- |
| `procurement_stock/repositories/globalStockRepository.ts` | `create_and_post_stock_movement` |
| `procurement_stock/repositories/stockMovementRepository.ts` | `create_stock_movement`, `add_stock_movement_line`, `post_stock_movement` |
| `procurement_stock/repositories/globalShipmentRepository.ts` | `post_shipment_outcome_stock`, `return_shipment_to_vendor` |
| Bills issue | `post_sales_invoice` → `commit_sales_bill_stock` |

---

## Related docs

- [Procurement spec](spec.md)
- [Shop order](../shop_order/spec.md)
- [Bills](../bills/spec.md)