# Sales Invoice Database Schema (v2)

Unified desk sales document for **wholesale**, **retail** (account + direct), and **dropship**. One accounting invoice model; extend via columns / charge types / RPCs — not a second invoice system.

> [!NOTE]
> Excludes Thrift Counter Sales (`thrift_sales_invoices`) — separate vertical.

**Related:** [workflow_flow.md](./workflow_flow.md) · [../stock/schema.md](../stock/schema.md) · [../shipment/schema.md](../shipment/schema.md) §4 · [../wallet/schema.md](../wallet/schema.md) · [SALES_INVOICE_ISSUES.md](../../SALES_INVOICE_ISSUES.md)

---

## 0. Ownership & layer rules (locked)

| Layer | Role |
| :--- | :--- |
| **`sales_invoices` pack** | One commercial + AR document per sale. **Books owner = parent** (`parent_tenant_id`). **Seller = child** (`issued_by_tenant_id`). |
| **Wallet / `wallet_ledger`** | Cash & entity money movements on **Pay / allocate** — not full GAAP books |
| **Shipment stamp** | Living unit cost (`shipment_items.landed_cost_bdt`) |
| **Reports / treasury** | **Actual** batch / investor P&L = invoice revenue − (current stamp × sold qty). Parent reads `parent_tenant_id`. |
| **Customer-facing print** | Child brand / face prices — **same** invoice row, different UI/print mode; never a second stock-deducting invoice |

```text
Invoice   = sell + frozen provisional cost + AR balances   ← one row, parent-owned
Wallet    = cash / dues when Pay runs
Report    = revenue − living stamp × sold qty   ← company actual profit (parent)
Print/UI  = child customer view  OR  parent accounting view
```

### Document ownership (locked)

One sale = **one** `sales_invoices` row. Lines may mix any parent shipments / any sister’s assigned batches. Do **not** split into N invoices per sister or per shipment. Child and parent screens are views of the same row.

| Field | Nested group | Standalone |
| :--- | :--- | :--- |
| `parent_tenant_id` | Parent (stock owner, books, number series) | Self |
| `issued_by_tenant_id` | Selling child (desk/shop create; customer print brand; profile catalog) | Same as `parent_tenant_id` |

| Who | Sees | Filter |
| :--- | :--- | :--- |
| Child desk | Create / list / pay / return / customer print | `issued_by_tenant_id` = that child |
| Parent | Rollup list, cost, margin, group reports | `parent_tenant_id` = parent |
| Parent UI issue | **No** — parent does not self-issue desk invoices | — |

**RLS:** Child members: read/write where `issued_by_tenant_id` is a tenant they belong to (cannot see sister invoices). Parent members: read where `parent_tenant_id` = parent.

**Profiles:** `billing_profiles` / `recipient_profiles` stay **per issuing child**. RPC: `profile.tenant_id` must equal `invoice.issued_by_tenant_id`.

**Number series:** unique `(parent_tenant_id, invoice_no)` — one pool per parent company.

**Cutover from live `global_invoices*`:** `issued_by_tenant_id = old.tenant_id`; `parent_tenant_id = old.parent_tenant_id`. Resolve duplicate `invoice_no` across sisters at migrate (prefix or resequence).

**Not this domain:** chart of accounts, journal vouchers, thrift sales, purchase/AP bills.

---

## 1. Custom Types & Enums

```sql
CREATE TYPE invoice_type AS ENUM (
  'wholesale',
  'retail',
  'dropship'
);

CREATE TYPE invoice_status AS ENUM (
  'draft',               -- Initial creation; soft-holds ATP; no stock deduct
  'revised',             -- Amended draft/proforma with updated items/quantities
  'proforma_generated',  -- Proforma invoice issued for customer approval/quote
  'issued',              -- Official commercial invoice issued; physical stock deducted & posted to AR
  'cancelled',           -- Voided/cancelled before settlement; stock restored, AR cleared
  'returned'             -- Customer returned items; stock restored & sales credit applied
);

CREATE TYPE payment_status AS ENUM (
  'unpaid',
  'partial',
  'paid',
  'refunded'
);

CREATE TYPE retail_billing_mode AS ENUM (
  'account',  -- Bill billing_profile
  'direct'    -- Walk-in / one-time; no billing profile
);

CREATE TYPE collection_source AS ENUM (
  'billing_profile',
  'recipient'
);

CREATE TYPE fulfillment_status AS ENUM (
  'pending',
  'packed',
  'shipped',
  'delivered'
);

CREATE TYPE invoice_charge_type AS ENUM (
  'shipping',
  'cod_fee',
  'packing',
  'print',
  'delivery',
  'other'
);

CREATE TYPE sales_return_status AS ENUM (
  'posted',
  'void'
);
```

---

## 2. Situation matrix (one table pack)

| Situation | `invoice_type` | `retail_billing_mode` | `billing_profile_id` | `collection_source` |
| :--- | :--- | :--- | :--- | :--- |
| Wholesale | `wholesale` | null | **Required** | `billing_profile` |
| Retail account | `retail` | `account` | **Required** | `billing_profile` |
| Retail direct | `retail` | `direct` | **null** | `recipient` |
| Dropship | `dropship` | null | **Required** (middle man) | Usually `recipient` for COD face; AR on middle man |

Charges: flexible rows — RPC allows types per situation (wholesale → mostly `shipping`; retail/dropship → COD / packing / print / delivery / shipping / other).

---

## 3. Schema Tables

### 3.1 `sales_invoices` (Header)

One row = one **accounting** sale. Totals cached for reads; derived from lines + charges.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary key |
| `parent_tenant_id` | BIGINT | Yes | **Parent** books owner (stock / reports). Standalone = self |
| `issued_by_tenant_id` | BIGINT | Yes | Selling **child** (desk/shop). Standalone = `parent_tenant_id` |
| `invoice_no` | TEXT | Yes | Unique per `(parent_tenant_id, invoice_no)` — company series |
| `invoice_type` | `invoice_type` | Yes | Channel |
| `retail_billing_mode` | `retail_billing_mode` | No | Retail only; null otherwise |
| `invoice_status` | `invoice_status` | Yes | Default `draft` |
| `fulfillment_status` | `fulfillment_status` | Yes | Ops only; default `pending` — does **not** affect margin/AR |
| `payment_status` | `payment_status` | Yes | Default `unpaid` |
| `billing_profile_id` | BIGINT | No | FK `billing_profiles`; must match `issued_by_tenant_id` when set |
| `recipient_profile_id` | BIGINT | No | FK `recipient_profiles`; optional; must match `issued_by_tenant_id` when set |
| `recipient_name` | TEXT | No | Snapshot (audit if profile changes) |
| `recipient_phone` | TEXT | No | Snapshot |
| `recipient_address` | TEXT | No | Snapshot |
| `collection_source` | `collection_source` | Yes | Who pays |
| `invoice_date` | DATE | Yes | Sale date |
| `due_date` | DATE | No | Credit terms |
| `subtotal_amount` | NUMERIC(12,2) | Yes | Σ line totals |
| `discount_amount` | NUMERIC(12,2) | Yes | Header discount |
| `charges_total` | NUMERIC(12,2) | Yes | Σ `sales_invoice_charges` |
| `settlement_discount_amount` | NUMERIC(12,2) | Yes | Post-post write-off; default `0` |
| `final_total_amount` | NUMERIC(12,2) | Yes | `subtotal − discount + charges − settlement_discount` |
| `paid_amount` | NUMERIC(12,2) | Yes | Allocated payments; default `0` |
| `due_amount` | NUMERIC(12,2) | Yes | `final_total − paid` |
| `courier_collected_amount` | NUMERIC(12,2) | No | COD reconcile — not a second invoice |
| `notes` | TEXT | No | Internal |
| `metadata` | JSONB | No | Escape hatch only — not core desk fields |
| `posted_at` / `posted_by` | TIMESTAMPTZ / UUID | No | Post audit |
| `voided_at` / `voided_by` | TIMESTAMPTZ / UUID | No | Void audit |
| `deleted_at` / `deleted_by` | TIMESTAMPTZ / UUID | No | Soft delete (drafts) |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | Audit |

**Cutover name:** target table family `sales_invoices*`. Live `global_invoices*` rename/recreate at migration — see issues.

---

### 3.2 `sales_invoice_items` (Lines)

Stock pick + accounting sell + provisional COGS snapshot.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary key |
| `invoice_id` | BIGINT | Yes | FK `sales_invoices` |
| `global_stock_id` | BIGINT | Yes | FK `global_stocks` — ATP / deduct grain |
| `shipment_item_id` | BIGINT | Yes | FK `shipment_items` — **required** for actual P&L join |
| `assigned_child_tenant_id` | BIGINT | No | Snapshot of `shipments.assigned_child_tenant_id` at add/post — report “whose batch”, not a second invoice |
| `name_snapshot` | TEXT | Yes | Product name at sale |
| `quantity` | INT | Yes | Qty sold |
| `unit_price` | NUMERIC(12,2) | Yes | **Accounting** unit sell price |
| `face_unit_price` | NUMERIC(12,2) | No | Optional customer-facing unit price (print only) |
| `line_discount` | NUMERIC(12,2) | Yes | Default `0` |
| `line_total_amount` | NUMERIC(12,2) | Yes | `(qty × unit_price) − line_discount` |
| `landed_cost_bdt` | NUMERIC(12,2) | No | Null in draft; set on **post**; **never** rewritten on cost revision |
| `return_quantity` | INT | Yes | Cumulative returned; default `0` |
| `metadata` | JSONB | No | Line notes |
| `created_at` / `updated_at` | TIMESTAMPTZ | Yes | Audit |

**Provisional vs actual**

| Value | Source | Mutable after post? |
| :--- | :--- | :---: |
| Accounting sell (`unit_price`) | Desk | No |
| Face sell (`face_unit_price`) | Desk / print | No (print uses snapshot) |
| Provisional COGS (`landed_cost_bdt`) | Stamp copy at post | No |
| Actual COGS | Living `shipment_items.landed_cost_bdt` × sold qty | Via shipment revision only |

---

### 3.3 `sales_invoice_charges` (Flexible fees)

Replaces hardcoded header charge columns. Same table for all invoice types.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary key |
| `invoice_id` | BIGINT | Yes | FK `sales_invoices` |
| `charge_type` | `invoice_charge_type` | Yes | Category |
| `label` | TEXT | No | Display override (e.g. courier name) |
| `amount` | NUMERIC(12,2) | Yes | Fee amount |
| `face_amount` | NUMERIC(12,2) | No | Optional customer-facing fee amount |
| `metadata` | JSONB | No | Tracking no., courier, etc. |

---

### 3.4 `sales_invoice_returns` + `sales_invoice_return_items`

Credit-note style returns. Posted invoice prices stay immutable.

#### Header

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary key |
| `parent_tenant_id` | BIGINT | Yes | Same as invoice — **parent** books owner |
| `issued_by_tenant_id` | BIGINT | Yes | Selling child (who processed the return) |
| `invoice_id` | BIGINT | Yes | Original **posted** invoice |
| `return_no` | TEXT | Yes | Document number |
| `status` | `sales_return_status` | Yes | `posted` \| `void` |
| `return_date` | DATE | Yes | Return date |
| `reason` | TEXT | No | Why |
| `total_return_amount` | NUMERIC(12,2) | Yes | Accounting credit |
| `total_return_charge` | NUMERIC(12,2) | Yes | Restocking/handling; default `0` |
| `created_by` / `created_at` | UUID / TIMESTAMPTZ | Yes | Audit |

#### Lines

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary key |
| `return_id` | BIGINT | Yes | FK return header |
| `invoice_item_id` | BIGINT | Yes | Original line |
| `global_stock_id` | BIGINT | Yes | Restore target |
| `quantity` | INT | Yes | Qty returned |
| `return_amount` | NUMERIC(12,2) | Yes | Accounting credit for goods |
| `return_face_amount` | NUMERIC(12,2) | No | Dropship / customer face credit if different |
| `return_charge_amount` | NUMERIC(12,2) | Yes | Default `0` |
| `unit_cost_snapshot` | NUMERIC(12,2) | No | Copy from invoice line at return (audit) |

On post return: bump `return_quantity`; post a `return_inbound` movement (default `held` @ returns; staff set **grade** + **availability**); recompute invoice `due_amount` / `payment_status` when credit applies. Do not increment the original sellable row.

---

### 3.5 Profiles & print (owned by sales_invoice module)

| Table | Purpose |
| :--- | :--- |
| `billing_profiles` | Buyer / reseller / dropship middle man — AR identity **per issuing child** (`issued_by_tenant_id`) |
| `recipient_profiles` | Reusable delivery parties; invoice always keeps name/phone/address snapshots |
| `invoice_brands` | Print presets **per issuing child** — customer print uses `issued_by_tenant_id` brand |

---

## 4. Customer-facing vs accounting document (locked)

**One invoice row.** Child vs parent is **UI / print**, not a second `sales_invoices` row that deducts stock. Different numbers for the end customer are the **face layer** on that same row.

| View | Audience | Uses | Stock / AR? |
| :--- | :--- | :--- | :---: |
| Child UI + customer print | Selling sister | Child `invoice_brands`; `face_unit_price` / `face_amount` (fallback accounting) | Same row — presentation |
| Parent UI + accounting print | Finance / books | `unit_price`, charge `amount`, AR totals, COGS | Yes — source of truth |

Shop-originated dropship may still emit a customer sheet from the order earlier in the flow; the desk **accounting** invoice remains this pack. See [SHOP_ORDER_DROPSHIP.md](../../shop_order/SHOP_ORDER_DROPSHIP.md).

Do **not** create two posted sales invoices for the same stock sale. Do **not** auto-split a mixed basket into per-sister or per-shipment invoices.

---

## 5. Core business logic

### 5.1 Formulas

- **Subtotal** = Σ `line_total_amount`
- **Charges** = Σ `sales_invoice_charges.amount`
- **Final** = `subtotal − discount_amount + charges − settlement_discount_amount`
- **Provisional line margin** = `line_total_amount − (quantity × landed_cost_bdt)` (frozen snapshot)
- **Actual COGS (reports)** = Σ (`shipment_items.landed_cost_bdt` × sold_qty) join on `shipment_item_id`

### 5.2 Wallet (money) vs invoice (AR fields)

| Event | Invoice | Wallet |
| :--- | :--- | :--- |
| Post (stock only) | `posted`; snapshot cost; `payment_status` stays `unpaid` unless paid inline | **Stub-skip** receivable — day one |
| Explicit Pay / allocate | Update `paid_amount`, `due_amount`, `payment_status` | **Required** ledger post |
| Void | Unpaid only; restore stock | No cash reverse if never paid |
| Return credit | Adjust due / payment_status | Pay/refund path when cash moves |

**Canonical ledger keys (locked):**

| Action | `source_type` | `source_id` |
| :--- | :--- | :--- |
| Pay / allocate / collection | `sales_invoice` | `sales_invoices.id` (as text) |
| Refund / return cash | `sales_invoice_return` | `sales_invoice_returns.id` (as text) |

Do **not** use `shipment_invoice` for desk sales. Wallet entity = tenant / billing profile / middleman — not the invoice row. Details: [../wallet/schema.md](../wallet/schema.md) · [../wallet/workflow_flow.md](../wallet/workflow_flow.md) Stage 2.

Wallet is **not** a chart of accounts. Company actual profit lives in **reports**, not wallet.

### 5.3 Post RPC (sketch)

`post_sales_invoice` in one transaction:

1. Validate `draft`; lines present; situation FKs valid (`profile.tenant_id = issued_by_tenant_id`).
2. ATP check: pickable sellable qty − other draft holds − shop carts ≥ line qty; `availability = sellable` and location `is_pickable` only.
3. Set `invoice_status = posted`; stamp `posted_at` / `posted_by`.
4. Per line: copy `shipment_item_id` from stock if needed; snapshot `landed_cost_bdt` from living stamp; snapshot `assigned_child_tenant_id` from the stock’s shipment if null; decrement `global_stocks.quantity`.
5. Recompute header totals. Do **not** auto-post wallet AR (day one).

### 5.4 Draft holds → ATP

ATP (Available to Promise): `Σ sellable ∧ location.is_pickable − draft invoice line qty − shop cart holds` — [stock/schema.md](../../procurement_stock/stock/schema.md). Draft/cart holds never set warehouse `availability = held`.

Invoice side: **query sum** of draft `sales_invoice_items.quantity` by `global_stock_id` (no dedicated hold table day one). Release on post (deduct), void, or delete draft line/invoice. Desk pick shows bin via stock’s `location_id`.

### 5.5 Extensibility

Same invoice pack for future desk features:

| Extend with | How |
| :--- | :--- |
| New fee | New `invoice_charge_type` or `other` + `label` |
| New print brand | `invoice_brands` |
| Shop → desk dropship | Create this invoice from order at accounting moment |
| Settlement / COD variance | Header fields already present |

**Out of band:** thrift, full GL, vendor bills, a second customer-invoice table, auto-split invoices per sister/shipment.

---

## 6. Entity sketch

```text
billing_profiles (child catalog) ──┐
recipient_profiles (child catalog) ┼──► sales_invoices
                                   │      parent_tenant_id = parent
                                   │      issued_by_tenant_id = selling child
                                   │         │
                                   │         ├──* sales_invoice_items ──► global_stocks
                                   │         │         └──► shipment_items (stamp / actual COGS)
                                   │         │         └── assigned_child_tenant_id (batch listing child)
                                   │         └──* sales_invoice_charges
                                   │
                                   └──► sales_invoice_returns ──* sales_invoice_return_items
```

---

## 7. Related docs

| Doc | Role |
| :--- | :--- |
| [workflow_flow.md](./workflow_flow.md) | Lifecycle stages |
| [../shipment/schema.md](../shipment/schema.md) §4 | Cost ownership / sell-first |
| [../stock/schema.md](../stock/schema.md) | ATP + availability |
| [../../SALES_INVOICE.md](../../SALES_INVOICE.md) | Domain UX / locked desk decisions (legacy target names may say `global_*`) |
| [../../SALES_INVOICE_ISSUES.md](../../SALES_INVOICE_ISSUES.md) | Open RPC / migration gaps |
| [../../REPORTING_TREASURY.md](../../REPORTING_TREASURY.md) | Margin reports + payments UI |
