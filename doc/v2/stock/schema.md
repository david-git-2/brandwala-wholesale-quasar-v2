# Stock & Inventory Database Schema

Parent warehouse qty + **bin/zone location** + how a child shop gets permission to list a batch.

**Design lock:** Locked in this schema + [PROCUREMENT_STOCK_ISSUES.md](../../PROCUREMENT_STOCK_ISSUES.md) (open gaps only).

---

## 0. Ownership & channel rules

| Layer | Storage | Role |
| :--- | :--- | :--- |
| **Physical on-hand** | `global_stocks` | Parent-owned. **Sole** inventory qty truth. |
| **Where (bin/zone)** | `stock_locations` + `global_stocks.location_id` | Place inside the one parent warehouse |
| **Who may list** | `shipments.assigned_child_tenant_id` (Option A) | List permission only — not a qty ledger. |
| **Sell truth (ATP)** | pickable sellable on-hand − draft invoice holds − shop cart holds | Desk + assigned shop share this. |
| **Shop display** | Real ATP **or** `display_quantity_override` | Cosmetics — checkout never trusts dummy. |
| **Holds** | Shop cart / invoice draft | Soft reservations — not a stock table. |
| **Warehouse ops** | Movement docs → update `quantity` / location / availability (§2.5) | Put-away, location transfer, availability transfer, return-in |
| **Multi-warehouse** | Deferred | Inter-site transfer later — day one = one warehouse per parent |

**Retired:** soft qty on `global_stock_allocations`.

**Standalone:** assign shipment to self (or treat own shipments as listable).  
**Nested:** one child per shipment (Option A). Multi-child same batch deferred. No day-one request/reassign.

**Complete ops model (locked):**

```text
Qty truth     = global_stocks
Sell gate     = availability (sellable | held | unsellable)
Where         = location_id → stock_locations
How changed   = stock movements (post RPC)
Cost          = shipment_item stamp
Who may list  = assign child
```

---

## 1. Availability (sell gate) — locked simple model

Do **not** drive ATP from tags. Tags = optional labels only ([UNIVERSAL_TAGGING_SYSTEM.md](../../tag/UNIVERSAL_TAGGING_SYSTEM.md)).

```sql
CREATE TYPE stock_availability AS ENUM (
  'sellable',     -- in ATP when location is pickable
  'held',         -- quarantine / inspection / return pending — out of ATP
  'unsellable'    -- damaged, expired, write-off pending — out of ATP
);

CREATE TYPE stock_location_kind AS ENUM (
  'zone',
  'bin',
  'staging',
  'returns'
);
```

| Field | Drives ATP? |
| :--- | :---: |
| `availability = sellable` | **Yes** (required) |
| `location.is_pickable` | **Yes** (required) |
| Optional detail note / future tag | **No** |

**Receive day one:** default 100% → `sellable` at **default** location (`is_default`). Split availability only when something is held/unsellable.

**Live bridge:** map `global_stock_types.is_sellable` → `sellable`; non-sellable types → `held` or `unsellable` until cutover.

> Older v2 sketch of a large `stock_condition` enum is **superseded** by this 3-way availability. Detail reasons are labels, not extra qty columns. Availability is **not** a physical bin.

---

## 2. Schema tables

### 2.1 `stock_locations` (bin / zone catalog) — locked

Physical place inside the **one** parent warehouse. Not a second qty ledger.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | PK |
| `parent_tenant_id` | BIGINT | Yes | Warehouse owner |
| `code` | TEXT | Yes | e.g. `A-01-03` — unique per `(parent_tenant_id, code)` |
| `name` | TEXT | Yes | Human label |
| `kind` | `stock_location_kind` | Yes | `zone` \| `bin` \| `staging` \| `returns` |
| `is_default` | BOOLEAN | Yes | Default put-away on receive (one per parent) |
| `is_pickable` | BOOLEAN | Yes | Counts toward ATP / sell pick; staging may be false |
| `sort_order` | INT | No | UI order |
| `is_active` | BOOLEAN | Yes | Default true |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | Audit |

**Seed day one (per parent):** e.g. `MAIN` (`bin`, default, pickable) + `RETURNS` (`returns`, not default, usually not pickable until released).

**Do not:** free-text location on stock only; soft allocation as fake location; multi-warehouse table day one.

---

### 2.2 `global_stocks` (the stock table)

Current on-hand only. **No** `returned_qty` / `sold_qty` / cost columns.

**Balance grain (locked):** `(shipment_item_id, availability, location_id)` → one qty row.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | PK — listing / cart / order FK target |
| `parent_tenant_id` | BIGINT | Yes | Owner tenant |
| `shipment_id` | BIGINT | Yes | FK shipments |
| `shipment_item_id` | BIGINT | Yes | FK shipment_items (cost via stamp) |
| `product_id` | BIGINT | Yes | FK products |
| `location_id` | BIGINT | Yes | FK `stock_locations` — **where** |
| `availability` | `stock_availability` | Yes | Default `'sellable'` |
| `quantity` | INT | Yes | On-hand in this row (≥ 0) |
| `detail_note` | TEXT | No | Optional human reason — not ATP |
| `deleted_at` / `deleted_by` | … | No | Soft delete |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | |

**Unique:** `(shipment_item_id, availability, location_id)` where not soft-deleted.

**Example**

| id | shipment_item_id | availability | location | qty |
| ---: | ---: | :--- | :--- | ---: |
| 1 | 501 | sellable | A-01 | 50 |
| 2 | 501 | sellable | B-02 | 30 |
| 3 | 501 | held | RETURNS | 20 |

Unit cost: join `shipment_item_id` → `landed_cost_bdt` ([../shipment/schema.md](../shipment/schema.md) §4).

---

### 2.3 Shipment → child assign (listing permission)

**Day one (locked):** Option A — this schema §2.3.

| Option | Shape | Status |
| :--- | :--- | :--- |
| **A (day one)** | `shipments.assigned_child_tenant_id` | One child (or self) per shipment |
| **B (later)** | `shipment_assignments` | Multi-child same batch |

No `quantity` on assign. Qty always from `global_stocks`.

**ATP (locked):**

```text
Σ quantity
  where availability = sellable
    and location.is_pickable = true
− draft invoice holds
− shop cart holds
```

**Listings (locked):** `shop_product_listings.global_stock_id` → this table. UNIQUE `(shop_id, global_stock_id)`.

| Candidate | Day one? | Why |
| :--- | :---: | :--- |
| **`global_stock_id`** | **Yes** | Correct grain for ATP / deduct / location |
| `shipment_item_id` alone | No | Collapses availability + location |
| `shipment_id` alone | No | Too coarse |
| `global_stock_allocation_id` | No | Soft ceiling — retired |

**Gate:** list only if `stock.shipment_id` is assigned to the shop’s tenant. Cart / order lines carry `global_stock_id`.

**Sell / pick**

| Channel | Day-one approach |
| :--- | :--- |
| Desk invoice | Search shows location; pick explicit `global_stock_id` |
| Shop checkout | Server may auto-allocate across pickable sellable rows (FIFO / location sort) — still deducts concrete `global_stock_id`s |

Shop UI does **not** need bin picker day one.

---

### 2.4 Legacy `global_stock_allocations` (migrate away)

Do not extend soft-qty semantics. Replace with §2.3 + listing `global_stock_id`.

---

### 2.5 Warehouse movements (solution locked; RPC names open)

**Status:** Pattern locked here. Exact table/RPC names — [issues §1](../../PROCUREMENT_STOCK_ISSUES.md). Build with location in the first movement cut (stock incomplete without it).

**Rule:** `global_stocks` = balances only. Never free-edit qty / availability / location in the UI. Every post-receive change is a **movement document** that posts into balances (same idea as wallet ledger vs balance).

#### Shape

| Layer | Role |
| :--- | :--- |
| `stock_locations` | Catalog of bins/zones |
| `global_stocks` | On-hand by `(availability, location)` |
| Movement header + lines | Ops ledger — type, status, reason, refs |
| Post RPC | Draft → post in one transaction; updates qty / availability / location rows |
| UI | Create / post / list movements only — no direct stock edits |

**Posted docs are immutable.** Undo via a new reverse document, not by editing history.

#### Movement types (build order)

| Type | Effect on `global_stocks` | In first cut? |
| :--- | :--- | :---: |
| Receive put-away | Create/add qty at chosen or **default** location + usually `sellable` | Yes (with receive) |
| Location transfer | Same availability: bin A → bin B | Yes |
| Availability transfer / adjustment | Same location: sellable ↔ held ↔ unsellable; write-off / cycle count | Yes |
| Return inbound | Add qty onto `held` @ returns (or chosen) location | Yes |
| Receive rollback | Reverse a receive post (qty + related stamps) cleanly | Yes |
| Partial receive cost share | Fair cost when only part of batch arrives | Later |
| Weight / cost input audit | History for package weight & cost revisions | Later |
| Inter-warehouse transfer | Second warehouse / site | Later |

#### Line grain (sketch)

Each movement line references enough keys to resolve/create the balance row: `shipment_item_id` (or `global_stock_id`), `qty`, `from_availability` / `to_availability`, `from_location_id` / `to_location_id` as needed by type. Header: `parent_tenant_id`, `type`, `status` (`draft` \| `posted`), optional `shipment_id` / reason, audit fields.

Exact table/RPC names left open until implementation; this section locks the **pattern**.

---

## 3. Relationships

```
[stock_locations] (parent warehouse bins/zones)
        ▲
        │ location_id
[shipments] (1 vendor, assigned_child_tenant_id)
     │
     ├── (N) [shipment_items]          ← landed_cost_bdt stamp
     └── (N) [global_stocks]           ← on-hand by availability + location
              └── shop_product_listings.global_stock_id

[stock_movements] ──post──► [global_stocks]
```
