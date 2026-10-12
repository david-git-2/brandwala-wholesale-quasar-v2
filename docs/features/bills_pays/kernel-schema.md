# Bills kernel — target schema

**Target.** Not live SQL. Live: `supabase/schemas/bills_pays/`. Product: [spec](spec.md). Numbers: [money-story](money-story.md). Gaps: [00-gaps](00-gaps.md). Build: [kernel plan](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

One money kernel. Other modules **plug in**. They do not own `bills` / `pays`. No second invoice table.

---

## 1. Tables (columns)

### `profiles` (party — already live)

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `parent_tenant_id` | bigint | Books owner |
| `profile_type` | enum | `tenant`, `customer`, `company`, `vendor`, `cargo`, `courier`, `investor` |
| `subject_id` | bigint | Unique with type |
| `name` | text | Print name |
| phone / address / group | … | Customer extras as live |

Every bill side is a **profile**. Tenant itself has a `tenant` (or `company`) profile. Vendor, cargo, customer, shop, courier — same table.

### `bills` (document shell)

| Group | Column | Type | Rule |
| :--- | :--- | :--- | :--- |
| Identity | `id` | bigint PK | |
| | `parent_tenant_id` | bigint | Books |
| | `issued_by_tenant_id` | bigint | Child that issued |
| | `document_no` | text | Unique per `parent_tenant_id` |
| From / to | `from_profile_id` | bigint FK `profiles` | **Bill from** — who issues / claims |
| | `to_profile_id` | bigint FK `profiles` | **Bill to** — who is billed |
| Paper | `document_kind` | enum | `standard` \| `credit_note` \| `debit_note` |
| | `parent_bill_id` | bigint FK `bills` | Required iff not `standard` |
| | `status` | enum | `draft` \| `issued` \| `voided` |
| | `document_date` | date | |
| | `due_date` | date | nullable |
| Settle | `settlement_kind` | enum | `take` \| `condition`. Null on AP / fee / notes. Not `status` |
| Plug | `source_type` | text | Adapter id, e.g. `shipment_cost`, `shop_order`, `compose` |
| | `source_id` | text | Adapter row id (string so any module) |
| | `source_key` | text | Optional slice, e.g. cost bucket |
| Issued money | `currency_code` | text | **Books** currency (default `BDT`). Due / paid / alloc use this |
| | `subtotal_amount` | numeric | Sum of line books amounts at issue |
| | `discount_amount` | numeric | |
| | `total_amount` | numeric | Issued face in books currency. Never silent-edit after issue |
| Comment | `note` | text | Not a credit note |
| Audit | `created_by`, `created_at`, `updated_at` | | |
| Extension | `channel_meta` | jsonb | Print / channel extras only. Not kernel money |

**Not on header:** `invoice_type`, `ap_shipment_id`, `ap_kind`, `shop_order_id`, `retail_billing_mode`, `recipient_*`, retail charge columns, `collection_source`. Those belong in **source** or **meta** or **lines**.

**Cached settlement (optional keep):** `paid_amount`, `due_amount`, `written_off_amount`, `payment_status`. UI/adapters should prefer `get_bill_net_balances`. Do not treat as source of truth.

**Direction (derived, do not store):** if `to_profile_id` is our tenant profile → **we owe** (pay out). If `from_profile_id` is our tenant profile → **they owe** (collect). Both sides can be non-tenant only if a later feature needs it; v1 always one side = tenant profile.

**Settlement (sell vs pay):** stock AR only.

| `settlement_kind` | Meaning | Sales | Pay |
| :--- | :--- | :--- | :--- |
| `take` | Sell now, pay later (credit / “they will pay”) | At **issue** | Collect anytime; bill stays **due** |
| `condition` | Goods out, not a firm sale yet | When **paid** | Same collect; unpaid is not guaranteed AR |

Walk-in: `take` only. AP / description-only bills: null. Who promised / extra words → `note`, not this field. Live today: `channel_meta.delivery_kind`.

**Checks**

- `from_profile_id` ≠ `to_profile_id` when both are set (null allowed until both sides exist)
- Both profiles same `parent_tenant_id` as the bill
- Notes: `document_kind ≠ standard` ⇒ `parent_bill_id` set; copy parent `source_*` and from/to unless the adapter overrides
- Unique standard plug: `(parent_tenant_id, source_type, source_id, source_key)` where `document_kind = standard` and source set
- `settlement_kind = condition` only when the bill has stock lines and is they-owe (from = tenant)

### `bill_lines`

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `bill_id` | bigint FK `bills` | CASCADE (live name today: `invoice_id`) |
| `parent_tenant_id` | bigint | |
| `line_kind` | text | `stock` \| `description` \| `charge` |
| `name_snapshot` | text | Always |
| `quantity` | numeric | `description` / `charge` may be `1` |
| `currency_code` | text | Line paper currency. Default = bill books currency |
| `unit_amount` | numeric | Unit in **this line’s** `currency_code` |
| `line_discount_amount` | numeric | Same currency as the line |
| `line_total_amount` | numeric | Line total in **this line’s** `currency_code` |
| `books_amount` | numeric | Same line in bill `currency_code` (BDT). Header totals sum this |
| `global_stock_id` | bigint | Only `stock` |
| `product_id`, snapshots | | Optional |
| `line_meta` | jsonb | Adapter extras (kg, SKU). Charge: `charge_type` (`shipping`, `wrapping`, `print`, …) |

Any module may issue a bill with **only description or charge lines** (fees, AP buckets, service, shipping). Stock lines optional. FIFO only when `global_stock_id` is set. **No `bill_charges` table.**

`charge` lines are commercial amounts on the same paper as stock. Header has no `shipping_charge` / `wrapping_charge` / `print_charge` / `charges_amount`.

**Currency groups (shipment paper and any mixed bill):** one bill, many line currencies. Print / adapters `GROUP BY currency_code` and `SUM(line_total_amount)` per group. Do not split the bill. Header `total_amount` stays the books (BDT) sum of `books_amount`. FX rate lives on the **pay**, not on each line (same as live shipment FX). If `books_amount` is unknown until paid, leave it null on draft; issue may still freeze BDT when the adapter has a rate, else freeze after first pay restamp — adapter rule, not a second bill.

### `pays`

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `tenant_id` | bigint | |
| `profile_id` | bigint | Party the money is with |
| `amount` | numeric | Books currency |
| `payment_date` | date | |
| `source` | text | `customer_cash`, `bank`, `store_credit`, `courier_remittance`, `ap_payout`, … |
| `cashbook_point_id` | bigint FK `cashbook_points` | **Where this money sat** (drawer, safe, …). Required when the tenant cashbook moves. Null only for profile-custody / leftover with no point |
| FX | `settlement_currency_code`, `foreign_amount`, `exchange_rate` | Foreign pays |
| leftover | `unallocated_amount` | Remainder after alloc |

Every pay is a transaction you can ask: which point holds (or held) this amount. Ledger rows copy this id. Live `pays` does **not** have this column yet.

### `pay_instruments`

Split tender: each slice has its own place.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `payment_id` | bigint FK `pays` | |
| `payment_method_code` | text | cash, bank, cheque, … |
| `amount` | numeric | |
| `cashbook_point_id` | bigint FK `cashbook_points` | Where **this slice** is. Cash → drawer/safe. Bank transfer → `bank_counter` (or that bank point). Sum of slices = `pays.amount` |
| `reference`, cheque fields | | as live |

If one instrument, `pays.cashbook_point_id` = that instrument’s point. If several, header point is the primary (first / cash) slice; **each instrument still stores its own** so you can find every amount.

Direction of cash is **which bills you alloc** (from/to), not a new pay product.

### `pay_allocations`

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `payment_id` | bigint FK `pays` | |
| `bill_id` | bigint FK `bills` | One column (drop live `invoice_id` + `global_invoice_id` pair) |
| `amount` | numeric | > 0 |

### `cashbook_accounts`

Leftover and custody per tenant / profile. Features do not write the ledger except via kernel pay RPCs.

### `cashbook_points` (live — cash point)

Till / safe / drawer under a **tenant** cashbook account. Not a stock location. Profile custody books do not use points in v1.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `parent_tenant_id` | bigint | |
| `cashbook_account_id` | bigint FK `cashbook_accounts` | Tenant operating book |
| `code` | text | Unique per account |
| `name` | text | |
| `kind` | enum | `drawer`, `safe`, `bank_counter`, `mobile`, `other` |
| `custodian_membership_id` | bigint | Optional staff |
| `is_active` | boolean | |
| `sort_order` | integer | |

### `cashbook_entries`

| Extra | Type | Rule |
| :--- | :--- | :--- |
| `cashbook_point_id` | bigint FK `cashbook_points` | Copy from the pay / instrument that wrote this line. Same amount, same place. Delete point → clear FK then drop row |

Pay in / pay out **must** pass a point when tenant cash moves (collect, AP payout, remittance into till/bank). `record_ledger_transaction(..., p_cashbook_point_id)` already exists; collect/AP writers do not pass it yet ([BP15](00-gaps.md)). Point-to-point transfer RPC is still open.

---

## 2. From / to (paper)

| Bill | From (`from_profile_id`) | To (`to_profile_id`) | Staff action |
| :--- | :--- | :--- | :--- |
| Wholesale / retail take | Tenant profile | Customer | Collect |
| Dropship merchant | Tenant profile | Shop (merchant) | Collect remittance |
| Shipment material | Vendor | Tenant profile | Pay out |
| Shipment freight / customs | Cargo | Tenant profile | Pay out |
| Manual fee we charge | Tenant | Any profile | Collect |
| Manual bill we received | Vendor / other | Tenant | Pay out |
| Credit note | Swap or same as parent | Same pair as parent | Settle open credit |

Print: **From** block = `from_profile` name/address. **To** block = `to_profile`. Delivery recipient (COD face) is **not** from/to — `channel_meta` or a 1:0..1 delivery snapshot if the adapter needs it.

---

## 3. Other modules plug in

Features call kernel. They pass **from, to, source, lines**. They do not add FKs on `bills`.

| Adapter | `source_type` | `source_id` | `source_key` | From | To |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Compose desk | `compose` | bill id after insert / null | — | chosen | chosen |
| Shipment AP | `shipment_cost` | shipment id | bucket (`material`, `freight`, …) | vendor/cargo | tenant. Lines grouped by `currency_code`; one bill per bucket |
| Shop / dropship | `shop_order` | order id | optional | tenant | merchant |
| Delivery close | `delivery_close` | paper id | — | tenant | customer |
| After-sales money | parent source copied | | | same | same | via `create_bill_adjustment` |

**Kernel RPCs (target names)**

| RPC | Job |
| :--- | :--- |
| `upsert_draft_bill` | from/to, lines, source, dates, currency, `settlement_kind` |
| `issue_bill` / `void_bill` | paper |
| `create_bill_adjustment` | CN/DN child |
| pay in / pay out + alloc | `bill_id` |
| `get_bill_net_balances` | issued ± notes − pays |
| `list_bills_for_source` | all documents for one adapter row |

**Do not:** new bill table per module; silent edit of issued `total_amount`; stock required; `invoice_type` as the generic classifier.

---

## 4. Live → target map

| Live `bills` | Target |
| :--- | :--- |
| `profile_id` | One of from/to (the counterparty). Fill the other with tenant profile |
| `invoice_type = ap` | from = vendor/cargo, to = tenant |
| `invoice_type` wholesale/retail/dropship | from = tenant, to = customer/shop |
| `invoice_no` / `invoice_status` | `document_no` / `status` |
| `ap_shipment_id` + `ap_kind` | `source_type=shipment_cost`, `source_id`, `source_key` |
| `shop_order_id` | `source_type=shop_order`, `source_id` |
| `channel_meta.delivery_kind` | `settlement_kind` (`take` \| `condition`) |
| `recipient_*` | not kernel; adapter meta |
| `bill_lines.invoice_id` | `bill_id` |
| `bill_charges` + header charge columns | `bill_lines` with `line_kind = charge`; then **drop** `bill_charges` |
| `pay_allocations.global_invoice_id` | `bill_id` |

Migrate: add from/to + source columns, backfill, adapters write them, then drop special FKs.
