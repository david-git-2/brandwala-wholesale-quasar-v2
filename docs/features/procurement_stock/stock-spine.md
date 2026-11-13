# Stock spine — warehouse quantity & movements

## As-built

| | |
| :--- | :--- |
| Purpose | **Single contract** for changing BW `global_stocks` quantity, location, availability, and grade |
| Truth | `global_stocks` · `stock_movements` · `stock_movement_lines` |
| Primary writer | `create_and_post_stock_movement` — grep `supabase/_domain_splits_archive/procurement/03_rpcs.sql` |
| Inbound lots | `post_shipment_outcome_stock` → internal `_stock_spine_*` (same tables; does **not** call `post_stock_movement`) |
| Dispatch deduct | `dispatch_delivery_paper` — `issue_outbound` movement, `reference_type=delivery_paper` |
| Sales deduct | `commit_sales_bill_stock` — skips qty when dispatch already posted for linked paper (BP17) |
| Product scope | **BW** parent-tenant warehouse only — not Koba/thrift ([business-models](../architecture/business-models.md)) |
| Procurement UX | [spec](spec.md) · inbound money → [money-kernel-wiring](money-kernel-wiring.md) |
| Trip document | **`delivery_paper`** is the as-built outbound trip (not `customer_deliveries`; see [PS15](../features/procurement_stock/00-gaps.md)) |

## Scope

| In | Out |
| :--- | :--- |
| Tier 1 & 2 warehouse actions → RPC map (below) | Money spine — bills/pays only |
| Planning vs posted, movement types | Shop `shop_customer_stocks` |
| Cycle count, dispatch, short-pick on delivery paper | Full ATP / promise engine |

---

## Layering

```text
Feature UI / close RPCs (delivery paper, demand close, returns, warehouse)
        │
        ▼  must end in a spine writer (below)
Stock spine
        │
        ▼
global_stocks (+ movement audit rows)
```

| Layer | Owns | Changes qty? |
| :--- | :--- | :--- |
| **Planning** | `delivery_paper_line.splits`, `preorder_demand.stock_picks` (legacy), pick dialogs | **No** |
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
| `issue_outbound` | Deduct only | `dispatch_delivery_paper` |
| `return_inbound` | Add or customer return path | Returns kernel, DP reject restock |
| `vendor_return` | Deduct (RTV) | `return_shipment_to_vendor` |
| `receive_rollback` | Deduct | Reserved; no public RPC yet |

Posted logic: `post_stock_movement`. One-shot: `create_and_post_stock_movement`. Multi-line desk: `create_stock_movement` → `add_stock_movement_line` → `post_stock_movement`.

---

## Spine writers

| Writer | Role | Typical `reference_type` |
| :--- | :--- | :--- |
| **`create_and_post_stock_movement`** | One-shot movement | `global_stock`, `delivery_paper`, `preorder_demand`, … |
| **`post_shipment_outcome_stock`** | Inbound lots + `receive_putaway` audit via `_stock_spine_upsert_receive_lot` / `_stock_spine_finalize_inbound_movement` | shipment id |
| **`dispatch_delivery_paper`** | Outbound deduct + cost snapshot on lines | `delivery_paper` |
| **`commit_sales_bill_stock`** | Bill issue deduct (if not dispatch-covered) | `sales_invoice` |
| **`approve_stock_physical_count`** | Variance → `adjustment` movement | `stock_physical_count` |
| **`return_shipment_to_vendor`** | RTV deduct | `shipment_return` |
| **Movement desk** | Draft multi-line | user-entered |

Returns: `10_returns_kernel.sql` · `apply_delivery_paper_outcome` (reject) · dropship finalize.

---

## Tier 1 — warehouse actions

| Action | Posted? | Primary RPC(s) | `movement_type` | UI |
| :--- | :--- | :--- | :--- | :--- |
| Receive vs shipment | Yes | `post_shipment_outcome_stock` → `_stock_spine_receive_shipment_outcomes` | `receive_putaway` | Shipment → Post to stock |
| Lot / expiry on receipt | Yes (lots) | `post_shipment_outcome_stock` · batch `paste_batch_code_items` | — | Shipment extras / batch |
| Putaway / relocate | Yes | `create_and_post_stock_movement` | `location_transfer` | Move location dialog |
| Hold / release | Yes | `create_and_post_stock_movement` | `availability_transfer` | Grade / availability |
| Reclassify (grade) | Yes | `create_and_post_stock_movement` | `grade_change` | Move grade dialog |
| Adjust (damage / shrink) | Yes | Movement desk or `create_and_post_stock_movement` | `adjustment` | Stock movements page |
| Plan pick | No | `save_delivery_paper_detail` | — | Delivery paper detail |
| Release reservation | No | `save_delivery_paper_detail` · cancel paper | — | Delivery paper |
| Pick confirm / pack | No | `mark_delivery_paper_packed` | — | Delivery paper |
| Dispatch / ship (stock-out) | Yes | `dispatch_delivery_paper` | `issue_outbound` | Delivery paper → dispatched |
| Customer return + disposition | Yes | `apply_delivery_paper_outcome` · `process_wholesale_invoice_return` | `return_inbound` · `grade_change` | DP outcomes / returns |

### Outbound: dispatch vs bill issue

| Step | RPC | Qty change? |
| :--- | :--- | :--- |
| Plan picks | `save_delivery_paper_detail` | No |
| Pack | `mark_delivery_paper_packed` | No |
| **Dispatch** | `dispatch_delivery_paper` | **Yes** — `issue_outbound` |
| Accept / condition bill | `apply_delivery_paper_outcome` → `post_sales_invoice` → `commit_sales_bill_stock` | **No duplicate** if dispatch movement exists for paper + stock line |

Counter sales **without** a delivery paper still deduct only on `commit_sales_bill_stock`.

---

## Tier 2 — warehouse actions

| Action | Posted? | Primary RPC(s) | Notes |
| :--- | :--- | :--- | :--- |
| Inbound inspect / QC | Yes (unsellable lots) | `post_shipment_outcome_stock` | Extras `kind=unsellable`, reasons `damaged` / `missing` — not a separate QC RPC |
| Cycle count | Yes on approve | `create_stock_physical_count` · `upsert_stock_physical_count_line` · `submit_stock_physical_count` · `approve_stock_physical_count` | Approve posts `adjustment` |
| Short-pick / backorder | Planning + row | `record_delivery_paper_short_pick` | Exception table; restores `preorder_demand.open_quantity` |
| Stage / consolidate | No | `update_delivery_paper_status` · `mark_delivery_paper_packed` | Status `packed` → `dispatched` via dispatch RPC |
| Pack verification | No | `mark_delivery_paper_packed` | Validates packed qty on lines |
| RTV outbound | Yes | `return_shipment_to_vendor` | `vendor_return` movement |
| Refund linkage | Money | `process_wholesale_invoice_return` | [Money kernel](README.md) |

---

## RPC index (stock spine)

| RPC | Args (summary) | Idempotency |
| :--- | :--- | :--- |
| `post_shipment_outcome_stock` | `p_shipment_id`, `p_stock_rows?` | Incremental post; auth at public wrapper only |
| `_stock_spine_receive_shipment_outcomes` | internal — same args | Called after `user_can_manage_books_tenant` |
| `create_and_post_stock_movement` | tenant, stock, qty, to_* , type, notes, reference | New movement each call |
| `create_stock_movement` / `add_stock_movement_line` / `post_stock_movement` | desk draft | Post once per movement id |
| `mark_delivery_paper_packed` | tenant, paper id | Re-call on `packed` ok |
| `dispatch_delivery_paper` | tenant, paper id | Returns existing movement if already dispatched |
| `save_delivery_paper_detail` | tenant, paper, items json | Planning only |
| `apply_delivery_paper_outcome` | tenant, paper, action, allocations | Outcome splits locked after apply |
| `record_delivery_paper_short_pick` | tenant, paper, line, picked qty, reason | Appends exception |
| `create_stock_physical_count` | tenant, location?, notes | New session |
| `upsert_stock_physical_count_line` | count id, stock, counted, recount? | Draft/counting only |
| `submit_stock_physical_count` | count id | → pending_approval |
| `approve_stock_physical_count` | count id | → posted; one adjustment movement |
| `return_shipment_to_vendor` | shipment, items json, outcome | Financial side + RTV movement |
| `commit_sales_bill_stock` | bill id | Skips deduct when dispatch covers line |
| `close_preorder_demand_document` | doc type/id, action | Legacy doc close; return picks → spine |

---

## Feature → spine map (quick)

| User action | RPC | Hits spine? |
| :--- | :--- | :--- |
| Save picks on delivery paper | `save_delivery_paper_detail` | No |
| Mark packed | `mark_delivery_paper_packed` | No |
| Dispatch paper | `dispatch_delivery_paper` | Yes |
| DP Reject outcome | `apply_delivery_paper_outcome` | Yes |
| DP Accept / Condition | outcome → bill → `commit_sales_bill_stock` | Yes if no prior dispatch deduct |
| Post to stock | `post_shipment_outcome_stock` | Yes |
| Shelf / grade / avail | `create_and_post_stock_movement` | Yes |
| Cycle count approve | `approve_stock_physical_count` | Yes |
| Short pick | `record_delivery_paper_short_pick` | Exception only; qty on save |

---

## Web entry points

| Path | RPC |
| :--- | :--- |
| `procurement_stock/repositories/globalStockRepository.ts` | `create_and_post_stock_movement` |
| `procurement_stock/repositories/stockMovementRepository.ts` | `create_stock_movement`, `add_stock_movement_line`, `post_stock_movement` |
| `procurement_stock/repositories/globalShipmentRepository.ts` | `post_shipment_outcome_stock`, `return_shipment_to_vendor` |
| `procurement_stock/composables/useDeliveryPaperDetail.ts` | `save_delivery_paper_detail`, `apply_delivery_paper_outcome` |
| Bills issue | `post_sales_invoice` → `commit_sales_bill_stock` |

FE wiring for dispatch / cycle count / short-pick RPCs: follow-up after backend contract (repositories not required for kernel doc).

---

## Related docs

| Doc | Use when |
| :--- | :--- |
| [Money kernel README](README.md) | Bills/pays — orthogonal |
| [procurement_stock spec](../features/procurement_stock/spec.md) US-2–US-4 | Shipment, demand, delivery paper |
| [00-gaps](../features/procurement_stock/00-gaps.md) PS30–PS35 | Residual WMS / trip design |
| [preorder-fulfillment-flow-as-built.md](../preorder-fulfillment-flow-as-built.md) | Target trip narrative vs delivery paper |

**Future:** declarative `supabase/schemas/procurement/05_stock_spine.sql`; unify `commit_sales_bill_stock` post path with `create_and_post_stock_movement` (BP17‑r).
