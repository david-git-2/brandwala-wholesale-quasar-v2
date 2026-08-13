# Shipment Lifecycle & Workflow Specification

Maps lifecycle stages to APIs / RPCs. Schema: [schema.md](./schema.md) (§4 landed-cost ownership). Engine: [shipment_engine.md](./shipment_engine.md).

---

## Lifecycle Overview

```
[ STAGE 1: DRAFT ]  ➔  [ STAGE 2: EDIT ]  ➔  [ STAGE 3: FINALIZE ]  ➔  [ STAGE 4: COST REVISION ]
  status: draft         status: in_transit      status: received        (stays received)
  • Create header       • Items CRUD          • Stamp landed_cost_bdt  • Update cost entries
  • (no cost entries     • Cost entries CRUD   • No wallet posts        • Recompute + re-stamp
    required yet)        • Boxes (verify)      • Post inventory         • Invoice snapshots stay frozen
                         • Weight / price      • Lock shipment          • Actual P&L via report join
                           balance             • Settle intent only
                         • Live cost preview
```

**Status vs progress:** `status` is the solid lifecycle above. Customer-facing journey labels (UK hub, airport, …) are **progress tags** (`shipment_progress` group via `entity_tags`) — never additional status values. See [schema.md](./schema.md) · [schema.md](./schema.md).

**Stage 2 note:** Editing / receive prep runs while `status = 'in_transit'` (live equivalent of Warehouse Received). Progress tags may change freely during Stages 1–3; they do not unlock finalize.
---

## Stage 1: Minimal Draft Creation (`status: 'draft'`)

* **Action**: User fills basic shipment details and creates a draft.
* **Execution**: Creates the shipment header only. Cost entries are added when entering rates (day one: one `product` + one `cargo`).
* **API / RPC**:
  * [create_shipment_draft.md](./rpc/create_shipment_draft.md) or [shipment_api.md](./api/shipment_api.md)

---

## Stage 2: Incremental Editing & Balancing (Items, Costs & Boxes)

* **Action**: Add items, cost entries, box verification weights; run purchase / weight balance.
* **Live Cost Preview**: Client [shipment_engine](./shipment_engine.md) over entries + items + `total_weight_kg` — UX only; **do not** write `landed_cost_bdt`.
* **Weight**:
  * Save cargo **invoice** weight on header: `total_weight_kg` ([shipment_api.md](./api/shipment_api.md))
  * Apply balance → mutate line `package_weight_gm` only — **never** overwrite `total_weight_kg`
  * Boxes = verification only ([shipment_box_api.md](./api/shipment_box_api.md))
* **Cost entries (day one)**:
  * `product`: amount (+ optional derive from Σ line purchase) + `exchange_rate`
  * `cargo`: `amount = cargo_kg × per_kg_rate` (UI) + `exchange_rate`
  * Multi FX / duty = more rows later — [shipment_cost_entry_api.md](./api/shipment_cost_entry_api.md)
* **APIs**:
  * Items — [shipment_item_api.md](./api/shipment_item_api.md)
  * Cost entries — [shipment_cost_entry_api.md](./api/shipment_cost_entry_api.md)
  * Boxes — [shipment_box_api.md](./api/shipment_box_api.md)

---

## Stage 3: Finalization & Inventory Posting (`status: 'received'`)

* **Action**: User marks received after verifying weights and rates (estimate OK — sell-first / cost-later).
* **Execution** (single RPC):
  1. Read `shipment_cost_entries`; compute effective rates **server-side** (authoritative).
  2. Stamp `landed_cost_bdt` on each `shipment_item` (living cost source of truth).
  3. **No wallet ledger posts** (day one — [issues §3](../../PROCUREMENT_STOCK_ISSUES.md)). `payment_source` / `entity_*` are settlement **intent** only; Pay / Settle is a later action.
  4. Post inventory (`inventory_added = true`) — stock qty only; **no cost column on stock**.
  5. Lock header against hard delete; block silent entry edits (must use Stage 4).

> Server does **not** trust client-computed landed costs.  
> Costing always runs; wallet never blocks receive.

---

## Stage 4: Cost Revision (post-finalization)

Supports: customer sells first, then settles true freight / FX / duty.

* **Trigger**: Actual bill or rate change after stock is live (and possibly after sales).
* **Action**: Edit `shipment_cost_entries` via **revision RPC** only (not raw upsert).
* **Execution**:
  1. Update entry(ies) (e.g. `exchange_rate` 168 → 172).
  2. Recompute via server engine.
  3. Re-stamp `landed_cost_bdt` on items.
  4. Optional: show old→new delta in UI (`costRevision.ts`).
  5. **No auto wallet posts** on revision ([issues §3](../../PROCUREMENT_STOCK_ISSUES.md)).
  6. **Do not** rewrite posted invoice / order line cost snapshots.

### Vendor return (stock ≠ cash)

| Outcome | Stock | Wallet |
| :--- | :--- | :--- |
| Return + **cash refund** | Qty down | Credit **tenant**; clear vendor as needed |
| Return + **store credit** | Qty down | Credit **vendor** wallet (they hold our value); **tenant cash unchanged** |
| Freight | Usually sunk | No cargo refund unless agent actually refunds |

Shipment remains `source_*` only — not a wallet holder.

### Downstream after revision

| Consumer | Behaviour |
| :--- | :--- |
| Unsold stock display | Joins new stamp via `shipment_item_id` |
| Posted invoices | Keep provisional `unit_cost_price` / `landed_cost_bdt` snapshot |
| Batch P&L / investor / treasury | `revenue − (current stamp × sold_qty)` — see [schema.md](./schema.md) §4.2 |

> Variance ledger rows are **not** required for day-one report truth.
