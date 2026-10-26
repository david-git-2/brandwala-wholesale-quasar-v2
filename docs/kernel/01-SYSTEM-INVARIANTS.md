# System invariants (rules of gravity)

**Job:** Core, non-negotiable ledger rules — issued-bill immutability (`total_amount`, profiles, currency), derived AR/AP from `from_profile_id` / `to_profile_id`, single-currency AP paper, cash points/pots, frozen FX on ledger lines. If a PR violates any rule here, it must not merge without an explicit invariant change (doc + team sign-off).

**Live vs target:** Rules below are the **target contract**. Live DB may lag — see [00-gaps](../features/bills_pays/00-gaps.md). Column names in SQL today often use `invoice_*` on `bills`; target names are in [kernel-schema](../features/bills_pays/kernel-schema.md).

---

## The 7 immutable invariants

### 1. Zero silent mutations

Once a bill is **issued** (`invoice_status = 'issued'` live; `status = 'issued'` target), these are **frozen**:

- `total_amount`
- `from_profile_id` / `to_profile_id` (live: derive from `profile_id` + `invoice_type` until from/to land)
- `currency_code` / books currency on the header

All commercial corrections after issue use **child bills** with `document_kind IN ('credit_note', 'debit_note')` and `parent_bill_id` set. Never `UPDATE` issued `total_amount` to “fix” a mistake.

`bills.note` is a comment only — not a credit note.

### 2. Derived direction

Never store `is_ar` or `is_ap`.

| Rule | Meaning |
| :--- | :--- |
| `from_profile_id` = tenant (books) profile | **AR** — they owe us (collect) |
| `to_profile_id` = tenant profile | **AP** — we owe them (pay out) |

Live shortcut: `invoice_type = 'ap'` ⇒ AP; wholesale/retail/dropship customer bills ⇒ AR. UI “they owe / we owe” must match this derivation.

### 3. Kernel isolation

No feature module may add a **foreign key** to `bills.id` or `pays.id` except kernel-owned children:

- `bill_lines`, `bill_charges` (legacy, fold to lines), `pay_allocations`, `pay_instruments`, `sales_return_items`, `invoice_write_offs`, note children on `bills.parent_bill_id`

Upstream features link with **`(source_type, source_id, source_key)`** on the bill row (target). Live exceptions being retired: `shop_orders.global_invoice_id`, `bills.ap_shipment_id`, `bills.shop_order_id` — do not add new FKs; migrate adapters to source plug ([BP9](../features/bills_pays/00-gaps.md)).

### 4. Single-currency paper rule

One **issued** shipment AP bill must not mix line currencies. Target: **one standard bill per `(bucket, currency)`** with `source_key = '{bucket}:{currency_code}'` (e.g. `freight:GBP`). Live `sync_shipment_ap_bills` may still emit one bill per bucket with mixed currencies — **do not extend that pattern**; fix toward WA15.

### 5. Frozen rate snapshot

When cash hits the ledger, copy the FX pair onto **`cashbook_entries`** (`exchange_rate`, `quote_currency_code`, `rate_date`, `base_amount`). Historical balances and shipment landed-cost feedback read **posted** lines and pay `exchange_rate`, not a live join to `books_exchange_rates`.

`books_exchange_rates` is a **default pick** at pay time only.

### 6. Physical cash traceability

Every `pays` row that moves **tenant operating cash** must carry a valid **`cashbook_point_id`** (drawer, safe, bank counter, …). Split tender: each `pay_instruments` slice has its own point. No “floating” tenant cash without a place ([BP15](../features/bills_pays/00-gaps.md) — column not on all writers yet).

Profile **custody** leftover may omit a point in v1; that is not tenant till cash.

### 7. Overpayment as custody

Unallocated pay amount is never deleted, merged into revenue, or dropped. It becomes **profile custody** via `cashbook_accounts` / ledger credit (`unallocated_amount` on `pays`, then `record_ledger_transaction` or collect writer). Apply to the next bill via alloc or leftover apply ([BP11](../features/bills_pays/00-gaps.md)), not a new AR bill.

---

## PR checklist (copy into review)

- [ ] Issued bill totals/parties/currency unchanged except via CN/DN child?
- [ ] No new FK to `bills` / `pays` from feature tables?
- [ ] Shipment AP bill single-currency (or explicitly scoped gap WA15)?
- [ ] Ledger lines freeze FX if foreign cash involved?
- [ ] Pay writer sets `cashbook_point_id` when tenant cash moves?
- [ ] Overpay path credits custody, not a second invoice?
- [ ] Every `SECURITY DEFINER` money RPC calls `assert_kernel_money_access` (or stricter) as **first** statement?
- [ ] No session-scoped `set_config` / `SET` on the money RPC path (Supabase transaction pooler)?
