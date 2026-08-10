# Thrift Sales — Schema (goal)

Workflow: [workflow.md](./workflow.md) · Examples: [scenarios.md](./scenarios.md)

**Inbound stock/shipment schemas are unchanged.** Cost always comes from `invoice_item.stock_id → thrift_stocks → thrift_shipments` via `compute_thrift_landed_unit_cost` at report time.

---

## Separation of concerns

| Concern | Where |
| :--- | :--- |
| What customer owes / paid | Invoice + lines + fee rows + `payment_status` |
| COD cash with courier | Invoice `cod_*` fields |
| Parcel track (Online) | Invoice `delivery_status` |
| Courier pick (Online) | Invoice `courier_provider_id` + snapshot `courier_provider` |
| Fee economics (Online) | Invoice **columns** `courier_*` / `cod_fee_*` / `packing_*` (amount + payer) — **not** `meta` |
| Tracking extras (Online) | Invoice `meta` only (`tracking_id`, `tracking_url`, …) |
| No-pickup / refuse (whole order) | Invoice RTO close (`close_reason = RTO`) |
| Post-pay return (partial or full) | **`thrift_sales_returns` + `thrift_sales_return_items`** |
| Shop logistics loss | Ledger `LOSS`/`EXPENSE` — **never deleted** on return |
| Per-line economics for reports | **`thrift_sales_pnl_lines`** |
| Money events | `thrift_accounting_ledger` |
| Unit cost / margin COGS | Live join to inbound shipment costing (**not** stored on invoice) |

### Online: two independent tracks on the same invoice (locked)

There is **no** separate delivery shipment table and **no** separate payment/collection document for the happy path. Both tracks live on `thrift_sales_invoices` and are updated via distinct RPCs.

| Track | Invoice fields | Write RPC | Does not |
| :--- | :--- | :--- | :--- |
| **Parcel** | `delivery_status` (+ RTO close fields when no-pickup) | `update_thrift_delivery_status` (RTO may share `revert_thrift_sales_invoice`) | Set `PAID` |
| **Cash** | `payment_status`, `cod_expected`, `cod_remitted_*`, optional remittance notes on `notes` | `record_thrift_cod_remittance` only (`outcome` includes write-off) | Change `delivery_status`, fees, `cod_expected`, lines, or write PnL |

`DELIVERED` ≠ `PAID`. Remittance can happen before or after deliver; either order is valid while invoice stays `ACTIVE` / `COD_PENDING` until cash settles (or `WRITTEN_OFF`). Remittance is a **cash-facts** edit surface only — see [workflow.md](./workflow.md) §3.

List filters / “COD queue” / delivery filters are **read projections** over invoice columns — not new write models.

### Two return situations (locked)

| Situation | Mechanism |
| :--- | :--- |
| **A.** Customer did **not** pick up; courier returns parcel | Whole-invoice **RTO** — no return document required |
| **B.** Customer paid / received goods; wants items back | **`thrift_sales_returns`** — **partial or full** line set |

---

## 1. `thrift_customers`

Unchanged intent: per-tenant customer book, upsert by normalized **primary** phone.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `tenant_id` | BIGINT → `tenants` | Yes | |
| `name` | TEXT | Yes | |
| `phone` | TEXT | Yes | Primary phone (display) |
| `phone_normalized` | TEXT | Yes | Unique with `tenant_id` — upsert key |
| `secondary_phone` | TEXT | No | Alternate phone; **not** unique / not part of upsert key |
| `address` | TEXT | No | Freeform street / house line (dropship-style shipping address) |
| `address_parts` | JSONB | Yes | BD catalog parts default `{}`: `{ "district", "thana", "post_code" }` — same static JSON catalogs as shop dropship (`bdAddressService`) |
| `notes` | TEXT | No | |
| `inserted_by` | TEXT | Yes | |
| `created_at` | TIMESTAMPTZ | Yes | |
| `updated_at` | TIMESTAMPTZ | Yes | |

Invoice also stores sale-day snapshots (`customer_name` / `phone` / `secondary_phone` / `address` / `address_parts`).

**Online create:** address line + `address_parts.district` + `address_parts.thana` required; `post_code` optional.  
**Upsert:** same phone → update name / secondary / address / address_parts / notes — does **not** insert a new customer when only address changes.

---

## 2. `thrift_sales_invoices`

Sale header = commercial document + Online parcel + COD + fee rows.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `tenant_id` | BIGINT → `tenants` | Yes | |
| `invoice_number` | TEXT | Yes | Unique `(tenant_id, invoice_number)`; `INV-YYYY-MM-#####` |
| `date` | TIMESTAMPTZ | Yes | Sale / create time |
| `sale_channel` | TEXT | Yes | `IN_STORE` \| `ONLINE` |
| `customer_id` | BIGINT → `thrift_customers` | No | |
| `customer_name` | TEXT | No | Snapshot |
| `customer_phone` | TEXT | No | Snapshot (primary) |
| `customer_secondary_phone` | TEXT | No | Snapshot |
| `customer_address` | TEXT | No | Snapshot freeform line; required Online happy path |
| `customer_address_parts` | JSONB | Yes | Snapshot `{ district, thana, post_code }`; Online requires district + thana |
| `payment_method` | TEXT | Yes | Offline default `CASH`; Online default `COD` |
| `payment_status` | TEXT | Yes | `PAID` \| `COD_PENDING` \| `REFUNDED` \| `PARTIALLY_REFUNDED` \| `WRITTEN_OFF` |
| `delivery_status` | TEXT | No | Online only; Offline always `null` |
| `total_invoice_amount` | NUMERIC(12,2) | Yes | Σ line `final_price × quantity` only (original sell; not reduced on partial return) |
| `courier_provider_id` | BIGINT → `thrift_courier_providers` | No | Online optional; system **or** own-tenant custom |
| `courier_provider` | TEXT | No | **Snapshot** of provider display name at create (survives rename/disable) |
| `courier_amount` | NUMERIC(12,2) | Yes | Forward delivery; `>= 0` |
| `courier_paid_by` | TEXT | No | `CUSTOMER` \| `SHOP`; required iff amount `> 0` |
| `cod_fee_amount` | NUMERIC(12,2) | Yes | Courier COD service fee ৳; default `0` |
| `cod_fee_paid_by` | TEXT | No | `CUSTOMER` \| `SHOP`; required iff amount `> 0` |
| `packing_amount` | NUMERIC(12,2) | Yes | Pack / print; default `0` |
| `packing_paid_by` | TEXT | No | `CUSTOMER` \| `SHOP`; required iff amount `> 0` |
| `return_courier_amount` | NUMERIC(12,2) | Yes | **RTO only** shop return/RTO courier on invoice close; default `0`. Post-pay returns store fee on `thrift_sales_returns` |
| `meta` | JSONB | No | Optional Online **extras only** — e.g. `{ "tracking_id", "tracking_url" }`. **Never** store fee amounts, payers, `courier_provider_id`, COD expected/remitted, or delivery status here (those are columns) |
| `cod_expected` | NUMERIC(12,2) | No | Derived on Online COD create; **immutable** at remittance (do not rewrite to accept shortfalls) |
| `cod_remitted_amount` | NUMERIC(12,2) | No | Last remittance call **replaces** this value (not cumulative) |
| `cod_remitted_at` | TIMESTAMPTZ | No | Timestamp of last remittance write |
| `cod_remittance_ref` | TEXT | No | Optional statement / SMS / deposit ref from last remittance |
| `close_reason` | TEXT | No | `null` while open/partial; `RTO` when no-pickup close; `CUSTOMER_RETURN` when **all** lines returned via returns |
| `economics_closed_at` | TIMESTAMPTZ | No | Last PnL write/update time |
| `created_by` | TEXT | Yes | |
| `notes` | TEXT | No | |
| `status` | TEXT | Yes | `ACTIVE` \| `PARTIALLY_RETURNED` \| `RETURNED` |
| `reverted_at` | TIMESTAMPTZ | No | Set on full RTO or when last line returned |
| `reverted_by` | TEXT | No | |
| `revert_reason` | TEXT | No | Legacy/detail; prefer `close_reason` + return docs |
| `revert_notes` | TEXT | No | |
| `created_at` | TIMESTAMPTZ | Yes | |
| `updated_at` | TIMESTAMPTZ | Yes | |

### Payment statuses

| Status | When |
| :--- | :--- |
| `PAID` | Offline create; or Online remittance `outcome = PAID` (staff may accept remitted &lt; `cod_expected`) |
| `COD_PENDING` | Online COD — sale real; cash not settled (`outcome = KEEP_PENDING` leaves this) |
| `PARTIALLY_REFUNDED` | Some lines returned; remainder still sold / cash settled |
| `REFUNDED` | Full RTO or all lines returned |
| `WRITTEN_OFF` | COD will never remit — same remittance RPC with `outcome = WRITTEN_OFF` |

`DELIVERED` does **not** auto-set `PAID`.

### Invoice status

| Status | Meaning |
| :--- | :--- |
| `ACTIVE` | No customer return completed (may still be in transit) |
| `PARTIALLY_RETURNED` | ≥1 return doc; ≥1 line still not returned |
| `RETURNED` | RTO whole order, or every sell line covered by returns |

### Delivery statuses (Online)

```text
PENDING → READY → IN_TRANSIT → DELIVERED
                              ↘ RETURNED   (no pickup / refuse — RTO)
```

| Status | Meaning |
| :--- | :--- |
| `PENDING` | Created; not packed |
| `READY` | Packed |
| `IN_TRANSIT` | With courier |
| `DELIVERED` | Customer received → write PnL as `DELIVERED` |
| `RETURNED` | Parcel never left with customer → **RTO** whole close |

Offline: `delivery_status` always `null`. Economics close as `DELIVERED` at create (walk-out).

### `cod_expected`

```text
cod_expected =
  total_invoice_amount
  + (courier_amount if courier_paid_by = CUSTOMER else 0)
  + (cod_fee_amount if cod_fee_paid_by = CUSTOMER else 0)
  + (packing_amount if packing_paid_by = CUSTOMER else 0)
```

### Channel rules

| Channel | Fees | Delivery | Payment on create | First PnL |
| :--- | :--- | :--- | :--- | :--- |
| `IN_STORE` | all amounts `0` | `null` | `PAID` | Immediate `DELIVERED` |
| `ONLINE` | staff amounts + payers | `PENDING` | `COD_PENDING` | At `DELIVERED` or `RTO` |

---

## 2b. `thrift_courier_providers` (**new** — system catalog + tenant customs)

Picker source for Online create. Two ownership modes in **one** table:

| Kind | `tenant_id` | `is_system` | Who manages |
| :--- | :--- | :---: | :--- |
| **System** (BD seed) | `NULL` | `true` | Platform only — tenants **cannot** edit/delete/rename |
| **Tenant custom** | set | `false` | Owning tenant can create / edit / deactivate / delete |

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `tenant_id` | BIGINT → `tenants` | No | `NULL` = global system row; non-null = tenant-owned |
| `code` | TEXT | Yes | Stable slug e.g. `pathao`, `my_van` |
| `name` | TEXT | Yes | Display label |
| `country_code` | TEXT | Yes | Default `BD` |
| `is_system` | BOOLEAN | Yes | `true` ⇒ immutable to tenants |
| `is_active` | BOOLEAN | Yes | Default `true`; inactive hidden from pickers (system may be deactivated by platform only) |
| `sort_order` | INT | Yes | UI order (system defaults below; tenants can set own) |
| `meta` | JSONB | No | **Extension bag** for future provider-specific extras (API keys later, website, support phone, notes). Default `{}`. **Never** put fee amounts / payers here |
| `created_at` | TIMESTAMPTZ | Yes | |
| `updated_at` | TIMESTAMPTZ | Yes | |

Suggested `meta` keys (non-breaking; add as needed later):

```json
{
  "notes": "string",
  "website": "https://…",
  "support_phone": "01…",
  "tracking_url_template": "https://…/{tracking_id}"
}
```

### Constraints (locked)

- `is_system = true` ⇒ `tenant_id IS NULL`
- `is_system = false` ⇒ `tenant_id IS NOT NULL`
- Unique system codes: unique partial index on `code` where `tenant_id IS NULL`
- Unique per tenant: unique `(tenant_id, code)` where `tenant_id IS NOT NULL`
- Index for picker: `(is_active, sort_order)` + tenant filter

### RLS / API rules

| Action | System rows | Tenant rows |
| :--- | :--- | :--- |
| List for picker | All tenants see active system | Plus own tenant’s active customs |
| Insert | Platform / migration seed only | Tenant with `thrift_sales` create/edit (or settings manage) |
| Update / deactivate | **Forbidden** to tenants | Own tenant only |
| Delete | **Forbidden** to tenants | Own tenant only (prefer deactivate if referenced) |

Trigger/RPC guard: any UPDATE/DELETE where `is_system = true` from tenant session → raise.

Invoice still stores `courier_provider_id` + **snapshot** `courier_provider` name so future renames of a custom provider (or platform seed label change) do not rewrite history.

### Seed (BD system rows — `is_system=true`, `tenant_id=null`)

Idempotent upsert by system `code`:

| code | name | sort |
| :--- | :--- | ---: |
| `pathao` | Pathao | 10 |
| `steadfast` | Steadfast | 20 |
| `redx` | RedX | 30 |
| `paperfly` | Paperfly | 40 |
| `ecourier` | eCourier | 50 |
| `deliveryman` | Deliveryman | 60 |
| `sundarban` | Sundarban Courier | 70 |
| `sa_paribahan` | SA Paribahan | 80 |
| `karatoa` | Karatoa Courier | 90 |
| `janani` | Janani Courier | 100 |
| `fastbee` | FastBee | 110 |

No need for a system `other` row — tenants add their own customs (`is_system=false`).

### UI

- Online create picker = **active system ∪ active customs for this tenant** (system first by `sort_order`, then tenant customs).  
- Settings (or sales settings): list own customs; add/edit/deactivate; system list shown read-only.  
- Pick → `courier_provider_id` + snapshot `name` onto invoice.

Fees **never** live on this table — still invoice columns.

---

## 3. `thrift_sales_invoice_items`

Sell lines only — **no cost / profit columns**. Original sell amounts stay (returns do not mutate line prices).

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `invoice_id` | BIGINT → invoices CASCADE | Yes | |
| `tenant_id` | BIGINT → `tenants` | Yes | |
| `stock_id` | BIGINT → `thrift_stocks` | Yes | Soft-delete only; join for COGS + inbound `shipment_id` |
| `sell_price` | NUMERIC(12,2) | Yes | |
| `discount_amount` | NUMERIC(12,2) | Yes | Default `0` |
| `final_price` | NUMERIC(12,2) | Yes | `sell_price - discount_amount` |
| `quantity` | INTEGER | Yes | Default `1` (thrift typically 1 unit / stock) |
| `created_at` | TIMESTAMPTZ | Yes | |
| `updated_at` | TIMESTAMPTZ | Yes | |

`total_invoice_amount = Σ (final_price × quantity)`.

A line is **returnable** if not already on a completed return item and invoice is not RTO-closed.

---

## 4. `thrift_sales_returns` (**new** — post-pay returns)

Customer paid / received goods (or Offline desk return). **Partial or full.**

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `tenant_id` | BIGINT | Yes | |
| `invoice_id` | BIGINT → invoices | Yes | |
| `return_number` | TEXT | Yes | Unique `(tenant_id, return_number)` e.g. `RET-YYYY-MM-#####` |
| `status` | TEXT | Yes | `COMPLETED` (v1 immediate; no approve workflow) |
| `refund_amount` | NUMERIC(12,2) | Yes | Σ returned line `final_price × qty` |
| `return_courier_amount` | NUMERIC(12,2) | Yes | Shop-paid return logistics; default `0` |
| `notes` | TEXT | No | |
| `created_by` | TEXT | Yes | |
| `created_at` | TIMESTAMPTZ | Yes | |
| `updated_at` | TIMESTAMPTZ | Yes | |

Not used for **RTO / no-pickup** (that stays on the invoice).

---

## 5. `thrift_sales_return_items` (**new**)

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `return_id` | BIGINT → returns CASCADE | Yes | |
| `tenant_id` | BIGINT | Yes | |
| `invoice_item_id` | BIGINT → invoice_items | Yes | Unique among completed returns (one return per line v1; thrift qty usually 1) |
| `stock_id` | BIGINT | Yes | |
| `quantity` | INTEGER | Yes | Must be `≤` invoice line qty; thrift default `1` |
| `condition` | TEXT | Yes | `SELLABLE` \| `DAMAGED` |
| `refund_amount` | NUMERIC(12,2) | Yes | Usually `final_price × quantity` |
| `created_at` | TIMESTAMPTZ | Yes | |

On complete: restore stock `AVAILABLE` if `SELLABLE`, else `DAMAGED`.

---

## 6. `thrift_sales_pnl_lines` (**new** — report fact table)

One row per invoice line after first economics close; **updated** when that line is later returned.

Does **not** store COGS (still live from inbound shipment).

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGSERIAL PK | Yes | |
| `tenant_id` | BIGINT | Yes | |
| `invoice_id` | BIGINT → invoices | Yes | |
| `invoice_item_id` | BIGINT → invoice_items | Yes | Unique |
| `stock_id` | BIGINT | Yes | |
| `inbound_shipment_id` | BIGINT | Yes | From `thrift_stocks.shipment_id` at write |
| `outcome` | TEXT | Yes | `DELIVERED` \| `RTO` \| `CUSTOMER_RETURN` |
| `return_id` | BIGINT | No | Set when outcome became `CUSTOMER_RETURN` via a return doc |
| `quantity` | INTEGER | Yes | |
| `sell_amount` | NUMERIC(12,2) | Yes | `final_price×qty` if still delivered; `0` if RTO / returned |
| `allocated_shop_delivery` | NUMERIC(12,2) | Yes | Default `0` |
| `allocated_shop_cod_fee` | NUMERIC(12,2) | Yes | Default `0` |
| `allocated_shop_packing` | NUMERIC(12,2) | Yes | Default `0` |
| `allocated_return_courier` | NUMERIC(12,2) | Yes | Default `0` |
| `allocated_fees_total` | NUMERIC(12,2) | Yes | Sum of the four |
| `cogs_is_loss` | BOOLEAN | Yes | Default `false`; `true` when return `condition = DAMAGED` (report still loads landed cost as loss) |
| `event_at` | TIMESTAMPTZ | Yes | Last economics event on this line |
| `event_date` | DATE | Yes | |
| `created_at` | TIMESTAMPTZ | Yes | |
| `updated_at` | TIMESTAMPTZ | Yes | |

Unique: `(invoice_item_id)`.

### Fee pool → allocate (value-based)

```text
line_value_i = final_price_i × quantity_i
V = Σ line_value_i   (scope = lines in the event)
share_i = line_value_i / V   (if V=0 → equal split)
```

| Outcome | `sell_amount` | Fee pools | COGS in report |
| :--- | :--- | :--- | :--- |
| `DELIVERED` | line value | Shop-paid delivery / COD fee / packing on **invoice** | landed × qty |
| `RTO` | `0` | Whole-invoice: full forward delivery + packing + invoice `return_courier_amount` | `0` (stock sellable) |
| `CUSTOMER_RETURN` | `0` | Keep that line’s prior shop delivery/packing allocations; add share of **this return’s** `return_courier_amount` across **returned lines only** | `0` if sellable; **landed × qty as loss** if `cogs_is_loss` |

Partial return example: lines A+B delivered; return only A → update PnL A to `CUSTOMER_RETURN`; PnL B stays `DELIVERED`.

---

## 7. `thrift_invoice_counters`

Monthly sequences for `INV-YYYY-MM-#####`. Optionally same pattern for `RET-YYYY-MM-#####` (separate counter row or `kind` column).

**Staff mistake:** counter is **never** decremented or reset — deleted numbers leave gaps (see workflow §6.3).

---

## 8. Writes matrix

| Action | Invoice / stock | Ledger | PnL | Counter |
| :--- | :--- | :--- | :--- | :--- |
| Create Offline | `CASH`/`PAID`/`ACTIVE`, fees `0`, `delivery_status=null`, `economics_closed_at`, stock `SOLD` | `REVENUE` = item total only | Insert `DELIVERED` (fees alloc `0`) | Allocate next |
| Create Online | `COD`/`COD_PENDING`/`ACTIVE`/`PENDING`, fees + `cod_expected`, `economics_closed_at=null`, stock `SOLD` | `REVENUE`; shop delivery/packing `EXPENSE` (no COD-fee ledger) | None yet | Allocate next |
| Mark `DELIVERED` | parcel only | No money change | Insert `DELIVERED` | — |
| **RTO / no-pickup** | Soft close: `RETURNED`, `REFUNDED`, `close_reason=RTO`, all stock back | `REFUND` full; `LOSS` uncollected delivery + return courier; keep packing expense | All lines → `RTO` | Unchanged |
| **Post-pay return** (partial/full) | Insert return + items; stock per condition; status `PARTIALLY_RETURNED` or `RETURNED`; payment `PARTIALLY_REFUNDED` or `REFUNDED` | `REFUND` = return `refund_amount`; `LOSS` = return courier | Returned lines → `CUSTOMER_RETURN` | Unchanged (return # separate) |
| COD remittance | Remitted fields + `payment_status` via `outcome` (`PAID` / stay `COD_PENDING` / `WRITTEN_OFF`); optional notes append | No row | No change | — |
| `STAFF_MISTAKE` | Hard-delete invoice + lines; restore stock `AVAILABLE`; **block** if returns exist | Delete invoice ledger rows (no REFUND/LOSS) | Delete PnL | **Unchanged** (number gap OK) |

Detail: [workflow.md](./workflow.md) §1 · §6 · [rpc/create_thrift_sales_invoice.md](./rpc/create_thrift_sales_invoice.md) · [rpc/revert_thrift_sales_invoice.md](./rpc/revert_thrift_sales_invoice.md).

---

## 9. Boundaries

| In | Out |
| :--- | :--- |
| RTO whole order on invoice | Partial RTO (courier returned only some SKUs mid-transit) |
| Post-pay partial **and** full returns via return docs | Complex multi-step approve/RMA portal |
| Damaged vs sellable on return line | Changing inbound shipment / stock costing schemas |
| Value allocation of shop logistics | Freezing COGS on invoice; outbound consignments table |
