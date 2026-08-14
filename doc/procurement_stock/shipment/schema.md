# Shipment Database Schema

**Module target:** v2 inbound (`shipments` + children).  
**Replaces (live):** header rate fields on `global_shipments` (`product_conversion_rate`, `cargo_conversion_rate`, `cargo_rate`, `transaction_rate`, invoice-total helpers).  
**Supersedes (older sketches):** `shipment_payments`, planned `global_shipment_cost_lines` (duty/insurance *beside* header rates).  
**Decision input:** [PROCUREMENT_STOCK_ISSUES.md](../../PROCUREMENT_STOCK_ISSUES.md) (open gaps) · engine: [shipment_engine.md](./shipment_engine.md)

---

## 1. Schema Fields

### 1.1 `shipments` (Universal Header)

Ops / identity container. **Zero financial rate fields** — money lives in `shipment_cost_entries`.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` |
| `tenant_shipment_id` | BIGINT | Yes | Sequential shipment # per tenant |
| `name` | TEXT | Yes | Shipment name / batch title |
| `status` | TEXT | Yes | **Lifecycle only:** `draft` \| `in_transit` \| `received` \| `cancelled`. Gates receive / stock. **Not** UK/airport/payment milestones — see progress tags below |
| `shipment_type` | TEXT | Yes | Solid enum: `'international'` \| `'local'` \| `'transfer'` \| `'thrift'` (thrift only if sharing this header). Economics branch — not progress labels |
| `vendor_id` | BIGINT | Yes | **One vendor per shipment** (product rule). Line-level vendor is not the target model |
| `assigned_child_tenant_id` | BIGINT | No | Optional: which child may **list** this batch (standalone = self / null). Listing permission only — not a qty ledger. |
| `cargo_company_id` | BIGINT | No | FK → `cargo_companies.id` (inbound freight agent). Create/dialog + `create_shipment_draft` prefill tenant **default** when omitted — [../cargo_company/schema.md](../cargo_company/schema.md) |
| `total_weight_kg` | NUMERIC | No | **Cargo invoice weight (kg)** — same role as live `received_weight`. Drives weight balance + cargo weight basis. Set only via explicit save — never overwritten by weight-balance apply |
| `inventory_added` | BOOLEAN | No | True after finalize posts stock |
| `metadata` | JSONB | No | Non-financial extras only |
| `deleted_at` / `deleted_by` | TIMESTAMPTZ / UUID | No | Soft delete |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | |

**Progress (customer-facing) — not a column enum**

| Mechanism | Detail |
| :--- | :--- |
| Tag group | Tenant-custom `shipment_progress` ([UNIVERSAL_TAGGING_SYSTEM.md](../../tag/UNIVERSAL_TAGGING_SYSTEM.md)) |
| Link | `entity_tags` with `entity_type = 'shipment'`, `entity_id = shipments.id` |
| UI rule | At most one active progress tag; optional `sort_order` on tags for stepper |
| API | List/get expose `status` + current progress tag; filter shipments by tag via `entity_tags` |
| Optional | Denormalized `progress_tag_id` on header for list speed only — SSOT remains `entity_tags` |
| Seed | `ensure_shipment_progress_tags(tenant_id)` + `set_global_shipment_progress_tag(shipment_id, tag_id)` |

Decision: [../../PROCUREMENT_STOCK_ISSUES.md](../../PROCUREMENT_STOCK_ISSUES.md) (open) · this schema

**Not on header (migrated away):**

| Live field | v2 home |
| :--- | :--- |
| `product_conversion_rate` | `product` entry `exchange_rate` |
| `cargo_conversion_rate` | `cargo` entry `exchange_rate` |
| `cargo_rate` | UI only → `cargo.amount = cargo_kg × per_kg_rate` |
| `transaction_rate` | Engine output only (blended display) |
| `cargo_invoice_total` / `purchase_invoice_total` | Entry `amount` (or UI inverse of rate) |
| `shipment_purchase_currency_id` / `shipment_cost_currency_id` | Prefer `currency_id` on each entry; header defaults are optional UX stubs only |

---

### 1.2 `shipment_cost_entries` (all money inputs)

One row = one money fact (payment / fee / FX slice). **Not** a JSONB blob on the header. Row identity supports edit-one-payment, SQL aggregates, wallet/variance later.

Effective rates are **computed by the engine**, never stored on the shipment header.

#### Columns

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | PK |
| `tenant_id` | BIGINT | Yes | Tenant anchor |
| `shipment_id` | BIGINT | Yes | FK → `shipments.id` (CASCADE) |
| `cost_type` | TEXT | Yes | Expense category — see types below |
| `amount` | NUMERIC | Yes | Total in **entry currency** (goods total or freight total — **not** per-kg) |
| `currency_id` | BIGINT | No | FK → currencies — currency of `amount` |
| `exchange_rate` | NUMERIC | Yes | → base (BDT). Default `1.00` for local / domestic |
| `payment_source` | TEXT | No | `'cash'` \| `'credit'` \| `'wallet'` — how this cost slice was / will be settled. Null OK day one |
| `entity_type` | TEXT | No | Payee wallet identity (e.g. `'vendor'`, `'cargo_company'`). **Not** `'shipment'`. Last-mile COD uses `'courier'` (separate) |
| `entity_id` | BIGINT | No | Payee id. Posts go to this entity’s wallet + tenant wallet; see money handoff below |
| `allocation` | TEXT | No | Stub: how this cost spreads to lines — see stubs |
| `metadata` | JSONB | No | Invoice ref, notes — **not** the cost journal |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | |

#### `cost_type` values

| Type | Day one | Role |
| :--- | :---: | :--- |
| `product` | **Yes** | Goods FX / purchase payments |
| `cargo` | **Yes** | Freight total (+ FX) |
| `duty` | Stub | Customs |
| `insurance` | Stub | |
| `labor` | Stub | |
| `washing` | Stub | |
| `transport` | Stub | |
| `handling` | Stub | |

Adding a type = new rows / enum label — **no new shipment columns**.

#### Day-one shape (current live behaviour)

Preserve today’s economics with **one `product` + one `cargo`** row (`exchange_rate = 1` when `shipment_type` is local/domestic).

| Live behaviour | Entry |
| :--- | :--- |
| Single goods FX | `{ cost_type: 'product', amount: Σ(unit_purchase_price × qty) or derived-from-lines, exchange_rate: <old product_conversion_rate> }` |
| Single freight | `{ cost_type: 'cargo', amount: cargo_kg × <old cargo_rate>, exchange_rate: <old cargo_conversion_rate> }` |

UI may still show “product FX”, “cargo £/kg”, “cargo invoice total” — those are **editors** that write the rows above.

**Multi-payment FX** (improved): more `product` rows with different `exchange_rate`; engine uses weighted average — no schema change.

```text
# Example — parity with current landedCost international sample
header.total_weight_kg = 15
entries = [
  { cost_type: 'product', amount: 1000, exchange_rate: 124.5 },
  { cost_type: 'cargo',   amount: 97.5,  exchange_rate: 1.0  },  // 15 × 6.5
]

# Example — multi FX (same table)
entries = [
  { cost_type: 'product', amount: 700, exchange_rate: 124.5 },
  { cost_type: 'product', amount: 300, exchange_rate: 126.0 },
  { cost_type: 'cargo',   amount: 97.5, exchange_rate: 1.0 },
]
```

#### Stubs (columns / types reserved — not required day one)

| Stub | Intent | Day one |
| :--- | :--- | :--- |
| Extra `cost_type`s | Duty, insurance, labor, … | Allow in check; UI can hide |
| `allocation` | `'by_weight'` \| `'by_value'` \| `'by_qty'` \| `'per_unit'` | Default: cargo → `by_weight`; extras when enabled → `by_value` or `by_qty` |
| `payment_source` + `entity_*` | Settlement **intent** only day one; no auto ledger post (§ money handoff) | Null OK; values OK without posting |
| Cost revision workflow | Re-stamp `landed_cost_bdt`; UI delta helper; **no** auto wallet delta | Required path after Ready Stock — no silent rate edits |
| Partial-receive cost share | Arrived qty only | Defer with warehouse ops |

#### Money handoff (locked — not a shipment wallet)

Cost entries are **inputs for landed cost**. Cash / credit lives in the [universal wallet](../wallet/schema.md).

| Holder | Wallet? |
| :--- | :---: |
| Tenant (shipment owner) | Yes — cash out on **Pay / Settle** (later) |
| Vendor / cargo agent (`entity_*`) | Yes — settle, advance, store credit |
| Shipment | **No** — use ledger `source_type` / `source_id` only |

| `payment_source` | Meaning (day one) |
| :--- | :--- |
| `cash` / `wallet` | Settlement **intent** — store on entry; **do not** auto-debit tenant on finalize |
| `credit` | Bought on account — intent only; open payable on vendor when Pay / Settle runs |
| null | Costing only — no wallet requirement |

**Day-one rule ([issues §3](../../PROCUREMENT_STOCK_ISSUES.md)):** Finalize and cost revision **never** post wallet ledger rows. They stamp cost + (on finalize) stock only. Auto-post on receive is an explicit non-goal.

**Later:** Explicit **Pay / Settle** action posts tenant ↔ payee ledger with `source_*` = shipment. Return-for-credit / cash refund remains a separate return flow (workflow Stage 4).

Return of goods for **store credit** (no cash refund): credit **vendor** wallet; tenant cash unchanged; stock qty down. Cash refund: credit tenant (+ clear vendor as needed).

#### Explicit non-goals

- Not a tenant formula builder
- Not a substitute for line `unit_purchase_price` / weights
- Not the wallet ledger (entries may point at payees; posts live in wallet)
- Not a shipment wallet
- Not auto wallet posts on finalize / cost revision (day one)
- Not thrift’s separate cost engine unless a later unification project

---

### 1.3 `shipment_items`

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | PK |
| `shipment_id` | BIGINT | Yes | FK → `shipments.id` |
| `product_id` | BIGINT | No | FK to product |
| `quantity` | INT | Yes | Qty in shipment |
| `unit_purchase_price` | NUMERIC | No | Unit price in purchase currency |
| `product_weight_gm` | NUMERIC | No | Product weight per unit (gm) |
| `package_weight_gm` | NUMERIC | No | Package contribution per unit (gm); **mutated by weight-balance apply** |
| `landed_cost_bdt` | NUMERIC | No | **Authoritative stamped** per-unit landed BDT. Written only on finalize / cost revision. Null while draft. |
| `metadata` | JSONB | No | |

> **Cost lives here — not on stock.** `global_stocks` holds qty + `shipment_item_id` only. Display / sell / reports resolve unit cost via this stamp (see §4).

---

### 1.4 `shipment_boxes`

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | PK |
| `shipment_id` | BIGINT | Yes | FK → `shipments.id` |
| `box_number` | TEXT | Yes | e.g. `BOX-01` |
| `weight_kg` | NUMERIC | Yes | Physical box weight |
| `metadata` | JSONB | No | |

**Boxes are verification-only.** They do **not** set `total_weight_kg`, do **not** drive weight-balance apply, and do **not** enter cargo costing.

---

## 2. Weight calculation (locked)

Same semantics as live procurement `received_weight` / D-PS13–14.

```text
line_gross_kg     = ((product_weight_gm + package_weight_gm) × quantity) / 1000
estimated_pack_kg = Σ line_gross_kg

cargo_kg = total_weight_kg   if total_weight_kg is set and > 0
         else estimated_pack_kg
```

| Rule | Detail |
| :--- | :--- |
| **Cargo invoice weight** | `shipments.total_weight_kg` only; explicit save |
| **Weight-balance apply** | Distributes `(total_weight_kg − estimated_pack_kg)` into line `package_weight_gm` only; **does not** change `total_weight_kg` |
| **Boxes** | Audit / verification; never used as `cargo_kg` |
| **Cargo entry amount** | Freight **total** in freight currency. Per-kg is UI: `amount = cargo_kg × per_kg_rate` at edit time |
| **Line cargo share** | Allocate `Σ(cargo entry amounts)` by `line_gross_kg / estimated_pack_kg`; if no weight basis, fall back to qty share |

---

## 3. Cost engine outputs (authoritative on finalize)

Derived from `shipment_cost_entries` + items + `total_weight_kg`. **Never** write effective rates back as header inputs.

```text
effective_rate(type) = Σ(amount × exchange_rate) / Σ(amount)   where cost_type = type

goods_bdt = Σ(amount × exchange_rate) for product
cargo_bdt = Σ(amount × exchange_rate) for cargo

# optional display blend (live transaction_rate parity):
blended = (goods_bdt + cargo_bdt) / (Σ product.amount + Σ cargo.amount)   when denom > 0

unit_base (purchase currency) = unit_purchase_price + (line_cargo_share / quantity)

landed_cost_bdt =
  local / domestic:  unit_base
  international:     unit_base × blended     # day-one parity with landedCost.ts
```

| Output | Formula / note |
| :--- | :--- |
| Effective rate per type | Weighted avg as above |
| Total BDT per type | `Σ(amount × exchange_rate)` |
| Cargo cost per kg (display) | `cargo_bdt / cargo_kg` when `cargo_kg > 0` |
| Per-item stamp | Write `shipment_items.landed_cost_bdt` on finalize / revision |

**Later (same table):** when `duty` / `labor` / etc. are live, prefer Σ BDT components allocated by `allocation` onto the line instead of stretching one blended FX forever.

---

## 4. Landed cost ownership (locked)

Closes live D-PS6 (frontend-only `landedCost.ts`). Supports **sell first, decide true cost later**.

| Layer | Stores | Mutable after sale? | Role |
| :--- | :--- | :---: | :--- |
| **Shipment item** `landed_cost_bdt` | Living / actual unit cost | **Yes** — cost revision only | Source of truth for lot cost |
| **Stock** `global_stocks` | Qty + FKs only | n/a | Does **not** own cost; join `shipment_item_id` |
| **Invoice / order line** | Sell + `unit_cost_price` / `landed_cost_bdt` **snapshot** | **Never** rewrite cost | Provisional COGS at sale; audit / returns |
| **Reports / investor / batch P&L** | Derived | Read-time | Join sell (invoice) + **current** stamp (shipment) for actual |

```text
Shipment  = living cost (stamp)
Stock     = quantity only
Invoice   = sell + frozen provisional cost
Report    = revenue from invoice − actual COGS from current stamp × sold qty
```

### 4.1 When the stamp is written

| Event | Action |
| :--- | :--- |
| Draft / edit | Engine preview only — **do not** persist `landed_cost_bdt` |
| Finalize (Ready Stock) | Server computes → stamps every item (may be estimate / provisional) |
| Cost revision | Edit entries → server recomputes → **re-stamps** items. Never silent header/entry edits without this path |

Downstream sale paths **read the stamp** — they do not rejoin cost entries or reimplement `landedCost.ts`.

### 4.2 Sell-first / cost-later (product rule)

1. Finalize may stamp a rough cost (or even `0` if product allows — prefer a best-known estimate).
2. Sale copies stamp → invoice line snapshot (`unit_cost_price` / `landed_cost_bdt`).
3. Later freight/FX/duty → **cost revision** updates shipment stamp only.
4. Posted invoice lines **stay frozen**.
5. True batch / investor P&L uses **current stamp**, not the frozen snapshot:

```text
revenue           = Σ (sell × qty)                         -- invoice
provisional_cogs  = Σ (unit_cost_snapshot × qty)           -- invoice (audit)
actual_cogs       = Σ (shipment_item.landed_cost_bdt × sold_qty)  -- join by shipment_item_id
true_profit       = revenue − actual_cogs
cost_adjustment   = provisional_cogs − actual_cogs         -- optional display column
```

Wallet variance posts (delta × qty) are an **optional stub** for cash/ledger UX — not required for report truth. Reports do not need a variance table if they join the current stamp.

### 4.3 Revision RPC (pattern locked — contract open)

| Locked | Open ([issues §2](../../PROCUREMENT_STOCK_ISSUES.md)) |
| :--- | :--- |
| Must go through one server revision path (not raw upsert after finalize) | Exact RPC name, args, return / error shape |
| Recompute engine server-side → re-stamp all affected items | Which `module_action` / role may revise |
| Invoice snapshots stay frozen; UI may show old→new delta | — |
| Wallet on revise = **stub-skip** ([issues §3](../../PROCUREMENT_STOCK_ISSUES.md)) | Pay / Settle RPC later |

Execution steps: [workflow Stage 4](./workflow_flow.md). Preview / delta helper: [shipment_engine.md](./shipment_engine.md).

### 4.4 Explicit non-goals

- Do **not** store authoritative landed cost on `global_stocks`
- Do **not** rewrite invoice line cost after post
- Do **not** leave rates editable after finalize without the revision RPC
- Do **not** keep frontend `landedCost.ts` as the sale / report authority (preview-only OK)
- Do **not** require a variance ledger table for day-one P&L truth

---

## 5. Relationships

```
shipments 1──* shipment_items          ← landed_cost_bdt stamp lives here
          1──* shipment_cost_entries   ← money inputs
          1──* shipment_boxes          ← verification only

shipment_items 1──* global_stocks      ← qty only; cost via FK
global_stocks   ──► invoice lines      ← sell + cost snapshot at sale
```

Cascade delete children with header (while `inventory_added = false`). Finalize locks hard delete.

---

## 6. Related docs

| Doc | Role |
| :--- | :--- |
| [shipment_engine.md](./shipment_engine.md) | Pure cost / weight / price engines + revision delta helper |
| [workflow_flow.md](./workflow_flow.md) | Draft → edit → finalize → revision |
| [api/shipment_cost_entry_api.md](./api/shipment_cost_entry_api.md) | CRUD for entries |
| [api/shipment_api.md](./api/shipment_api.md) | Header CRUD |
| [api/shipment_item_api.md](./api/shipment_item_api.md) | Lines + bulk weight/price balance |
| [api/shipment_box_api.md](./api/shipment_box_api.md) | Verification boxes |
| [../stock/schema.md](../stock/schema.md) | Qty pool — no cost column |
| [../invoice/schema.md](../invoice/schema.md) | Sell + provisional cost snapshot |
