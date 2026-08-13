# Stock & Inventory Database Schema

Parent warehouse qty + how a child shop gets permission to list a batch.

**Design lock:** Locked in this schema + [PROCUREMENT_STOCK_ISSUES.md](../../PROCUREMENT_STOCK_ISSUES.md) (open gaps only).

---

## 0. Ownership & channel rules

| Layer | Storage | Role |
| :--- | :--- | :--- |
| **Physical on-hand** | `global_stocks` | Parent-owned. **Sole** inventory qty truth. |
| **Who may list** | `shipments.assigned_child_tenant_id` (Option A) | List permission only — not a qty ledger. |
| **Sell truth (ATP)** | `sellable on-hand − draft invoice holds − shop cart holds` | Desk + assigned shop share this. |
| **Shop display** | Real ATP **or** `display_quantity_override` | Cosmetics — checkout never trusts dummy. |
| **Holds** | Shop cart / invoice draft | Soft reservations — not a stock table. |
| **Warehouse ops** | Movement docs → update `quantity` (§2.4) | Return-in, availability transfer, write-off — deferred. |
| **Transfer** | Deferred | Multi-location later. |

**Retired:** soft qty on `global_stock_allocations`.

**Standalone:** assign shipment to self (or treat own shipments as listable).  
**Nested:** one child per shipment (Option A). Multi-child same batch deferred. No day-one request/reassign.

---

## 1. Availability (sell gate) — locked simple model

Do **not** drive ATP from tags. Tags = optional labels only ([UNIVERSAL_TAGGING_SYSTEM.md](../../tag/UNIVERSAL_TAGGING_SYSTEM.md)).

```sql
CREATE TYPE stock_availability AS ENUM (
  'sellable',     -- in ATP
  'held',         -- quarantine / inspection / return pending — out of ATP
  'unsellable'    -- damaged, expired, write-off pending — out of ATP
);
```

| Field | Drives ATP? |
| :--- | :---: |
| `availability` | **Yes** |
| Optional detail note / future tag (`box_damaged`, …) | **No** |

**Receive day one:** default 100% → `sellable`. Split only when something is held/unsellable.

**Live bridge:** map `global_stock_types.is_sellable` → `sellable`; non-sellable types → `held` or `unsellable` until cutover.

> Older v2 sketch of a large `stock_condition` enum is **superseded** by this 3-way availability. Detail reasons are labels, not extra qty columns.

---

## 2. Schema tables

### 2.1 `global_stocks` (the stock table)

Current on-hand only. **No** `returned_qty` / `sold_qty` / cost columns.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | PK — listing / cart / order FK target |
| `parent_tenant_id` | BIGINT | Yes | Owner tenant |
| `shipment_id` | BIGINT | Yes | FK shipments |
| `shipment_item_id` | BIGINT | Yes | FK shipment_items (cost via stamp) |
| `product_id` | BIGINT | Yes | FK products |
| `availability` | `stock_availability` | Yes | Default `'sellable'` |
| `quantity` | INT | Yes | On-hand in this bucket (≥ 0) |
| `detail_note` | TEXT | No | Optional human reason (e.g. box damaged) — not ATP |
| `deleted_at` / `deleted_by` | … | No | Soft delete |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | |

**Example**

| id | shipment_item_id | availability | qty |
| ---: | ---: | :--- | ---: |
| 1 | 501 | sellable | 80 |
| 2 | 501 | unsellable | 20 |

Unit cost: join `shipment_item_id` → `landed_cost_bdt` ([../shipment/schema.md](../shipment/schema.md) §4).

### 2.2 Shipment → child assign (listing permission)

**Day one (locked):** Option A — this schema §2.2.

| Option | Shape | Status |
| :--- | :--- | :--- |
| **A (day one)** | `shipments.assigned_child_tenant_id` | One child (or self) per shipment |
| **B (later)** | `shipment_assignments` | Multi-child same batch |

No `quantity` on assign. Qty always from `global_stocks`.

**ATP (locked):** `Σ quantity where availability = sellable` − invoice draft holds − shop cart holds.

**Listings (locked):** `shop_product_listings.global_stock_id` → this table. UNIQUE `(shop_id, global_stock_id)`.

| Candidate | Day one? | Why |
| :--- | :---: | :--- |
| **`global_stock_id`** | **Yes** | Correct grain for ATP / deduct |
| `shipment_item_id` alone | No | Collapses availability buckets |
| `shipment_id` alone | No | Too coarse |
| `global_stock_allocation_id` | No | Soft ceiling — retired |

**Gate:** list only if `stock.shipment_id` is assigned to the shop’s tenant. Cart / order lines carry `global_stock_id`.

### 2.3 Legacy `global_stock_allocations` (migrate away)

Do not extend soft-qty semantics. Replace with §2.2 + listing `global_stock_id`.

### 2.4 Warehouse movements (deferred — solution locked)

**Status:** Not required before assign + ATP cutover. Gap list: [issues §1](../../PROCUREMENT_STOCK_ISSUES.md).

**Rule:** `global_stocks` = balances only. Never free-edit qty / availability in the UI. Every post-receive change is a **movement document** that posts into balances (same idea as wallet ledger vs balance).

#### Shape (when built)

| Layer | Role |
| :--- | :--- |
| `global_stocks` | On-hand by availability (unchanged role) |
| Movement header + lines | Ops ledger — type, status, reason, refs |
| Post RPC | Draft → post in one transaction; updates `quantity` / availability rows |
| UI | Create / post / list movements only — no direct stock edits |

**Posted docs are immutable.** Undo via a new reverse document, not by editing history.

#### Day-one movement types (build order)

| Type | Effect on `global_stocks` |
| :--- | :--- |
| Availability transfer / adjustment | Move qty between `sellable` ↔ `held` ↔ `unsellable`; write-off / cycle count (reduce qty) |
| Return inbound | Add qty onto a stock row (usually `held`) |
| Receive rollback | Reverse a receive post (qty + related stamps) cleanly |

#### Deferred beyond first movement cut

| Type | Why later |
| :--- | :--- |
| Partial receive cost share | Needs fair cost split when only part of a batch arrives |
| Weight / cost input audit | History for package weight & cost revisions (ties to cost-revision RPC) |
| Multi-location transfer | Only if more than one warehouse |

#### Line grain (sketch)

Each movement line references a `global_stock_id` (or enough keys to resolve/create the availability row), `qty`, and for transfers `from_availability` / `to_availability`. Header carries `parent_tenant_id`, `type`, `status` (`draft` \| `posted`), optional `shipment_id` / reason, audit fields.

Exact table/RPC names left open until implementation; this section locks the **pattern**, not the migration SQL.

---

## 3. Relationships

```
[shipments] (1 vendor, assigned_child_tenant_id)
     │
     ├── (N) [shipment_items]          ← landed_cost_bdt stamp
     └── (N) [global_stocks]           ← on-hand by availability
              └── shop_product_listings.global_stock_id

[stock_movements] (deferred) ──post──► [global_stocks]
```
