# Bills kernel — target schema

**Target.** Not live SQL. Live: `supabase/schemas/bills_pays/`. **Feature map:** [README.md](README.md). Product scope: [spec](spec.md). Numbers: [money-story](money-story.md). Gaps: [00-gaps](00-gaps.md).

One money kernel. Other modules **plug in**. They do not own `bills` / `pays`. No second invoice table.

---

## 0. Read order (do not drift)

| Role | Open (in order) |
| :--- | :--- |
| **Everyone** | [spec](spec.md) + [00-gaps](00-gaps.md) |
| **Schema / RPC change** | This file + [REFERENCE](../../kernel/REFERENCE.md) + grep `supabase/schemas/` |
| **Verify behavior** | [tests](tests.md) golden A–D |
| **Dropship numbers** | [money-story](money-story.md) only |

**Boundaries:** Features never `INSERT` kernel tables. **No FIFO inside `issue_bill`** — warehouse first, then issue ([BP17](00-gaps.md)). No domain payout RPCs — use `source_type` + `post_money_out` ([BP24](00-gaps.md)). Balances from `bill_settlements` (target) / `get_bill_net_balances` (live). Lifecycle (`draft`/`issued`/`voided`) ≠ settlement (`due`/`partial`/`paid`).

**Layers:** bill (paper) → settlements → pay (cash) → cashbook (till/custody). Client calls `supabase.rpc` only; writes are `SECURITY DEFINER` + `assert_kernel_money_access`.

**Money spine gate:** New pay/bill writers use `_kernel_record_pay_bill_settlement` / [BP25](00-gaps.md) idempotency; [BP18‑c](00-gaps.md) cutover shipped. Build order: [00-gaps](00-gaps.md).

### 0b. Global lock order (all money RPCs)

Use one ordering in every writer that touches more than one row. Deadlocks = wrong order, not “retry forever”.

| Order | Resource | When |
| :--- | :--- | :--- |
| 1 | `pg_advisory_xact_lock(hashtext('shipment_money:' \|\| shipment_id))` | `sync_shipment_ap_bills`, `issue_shipment_ap_bills`, AP payout / landed-cost refresh for that shipment ([WA15](00-gaps.md)) |
| 2 | `bills` | `SELECT … FOR UPDATE` — sort locked bill ids `ORDER BY id ASC` |
| 3 | `pays` | `FOR UPDATE` when re-allocating or reversing |
| 4 | Profile custody `cashbook_accounts` | `FOR UPDATE ORDER BY id` |
| 5 | `cashbook_point_pots` | `FOR UPDATE ORDER BY cashbook_point_id, currency_code` |

**Pay + alloc:** always lock **target bill(s)** before reading `get_bill_net_balances` / inserting settlements. **Draft** edits use optimistic `version` / `updated_at` only on draft rows; **issued** paths use pessimistic bill locks only.

**Cache columns:** `due_amount` / `payment_status` — if kept live, update only inside the same transaction as settlement inserts (or stop writing them after BP18 cutover). Never the sole guard for alloc limits.

### Target write / read RPCs

| RPC | Job |
| :--- | :--- |
| `upsert_draft_bill` / `issue_bill` / `void_bill` | Paper ([BP9](00-gaps.md)) |
| `create_bill_adjustment` / `issue_bill_adjustment` | CN/DN |
| `post_money_in` / `post_money_out` | Pay + optional settlements |
| `apply_settlement_to_bill` | Custody / CN / leftover → bill (live: `apply_leftover_to_bill`, [BP18](00-gaps.md)) |
| `reverse_pay` | Unwind pay; bill lifecycle stays issued |
| `get_bill_net_balances`, `list_*_for_source` | Reads ([BP10](00-gaps.md)) |
| `v_kernel_bill_summaries` | Paginated read view ([BP23](00-gaps.md)) |

### Live RPCs (wired today)

| Job | RPC |
| :--- | :--- |
| Collect + alloc | `post_customer_receipt_with_allocations` |
| Void collect | `void_customer_receipt` |
| Apply pay slice to bill | `allocate_payment_to_global_invoice` |
| AP payout | `post_ap_payout_with_allocations` |
| Merchant profit | `dispense_middleman_payout_from_tenant` (retire [BP24](00-gaps.md)) |
| AR draft/issue | `create_sales_invoice_from_payload`, `issue_wholesale_invoice`, `post_sales_invoice` |
| Void bill | `void_sales_invoice` |
| CN/DN | `create_bill_adjustment`, `issue_bill_adjustment` |
| Shipment AP | `sync_shipment_ap_bills`, `lock_global_shipment_costs`, `issue_shipment_ap_bills` |
| Balance | `get_bill_net_balances` |

Code: `web/src/modules/bills_pays/repositories/`. UI: `/app/bills`, `/app/finance/payments`, `/app/wallet`.

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
| | `status` | enum | Target name `lifecycle_status`: `draft` \| `issued` \| `voided` (live: `invoice_status`) |
| | `document_date` | date | |
| | `due_date` | date | nullable |
| Settle | `settlement_kind` | enum | `take` \| `condition`. Null on AP / fee / notes. Not lifecycle/settlement status |
| Plug | `source_type` | text | Adapter id, e.g. `shipment_cost`, `shop_order`, `compose` |
| | `source_id` | text | Adapter row id (string so any module) |
| | `source_key` | text | Optional slice, e.g. shipment cost bucket, or `{bucket}:{currency_code}` for shipment AP |
| Txn face | `txn_currency_code` | text | What vendor/customer sees (e.g. `USD`). One txn currency per standard AP bill ([WA15](00-gaps.md)) |
| | `txn_total_amount` | numeric | Face in `txn_currency_code` at issue |
| | `books_exchange_rate` | numeric | **Books per 1 txn** frozen at `issue_bill` |
| Issued money | `currency_code` | text | **Books** currency (default `BDT`) |
| | `subtotal_amount` | numeric | Sum of line books amounts at issue |
| | `discount_amount` | numeric | |
| | `total_amount` | numeric | Issued face in books currency. Never silent-edit after issue |
| Comment | `note` | text | Not a credit note |
| Audit | `created_by`, `created_at`, `updated_at` | | |
| Extension | `channel_meta` | jsonb | Print / channel extras only. Not kernel money |

**Not on header:** `invoice_type`, `ap_shipment_id`, `ap_kind`, `shop_order_id`, `retail_billing_mode`, `recipient_*`, retail charge columns, `collection_source`. Those belong in **source** or **meta** or **lines**.

**Settlement status (derived or cached):** Target `settlement_status`: `unpaid` \| `partial` \| `settled` \| `over_credited`. Live: `payment_status` + optional `paid_amount`, `due_amount`, `written_off_amount`. Source of truth: sum of `bill_settlements` vs open face; prefer `get_bill_net_balances`. Do not treat cache columns as sole truth.

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
- Unique **active** standard plug (partial index, void excluded):

```sql
CREATE UNIQUE INDEX uq_active_standard_bill
ON bills (parent_tenant_id, source_type, source_id, COALESCE(source_key, ''))
WHERE document_kind = 'standard'
  AND source_type IS NOT NULL
  AND source_id IS NOT NULL
  AND status <> 'voided';
```

  Live `bills_source_plug_uidx` may omit void filter until [BP20](00-gaps.md). Legacy `bills_ap_shipment_kind_uidx` coexists until WA15 backfill.

- `settlement_kind = condition` only when the bill has stock lines and is they-owe (from = tenant)
- `upsert_draft_bill` / `issue_bill`: require matching `version` or `updated_at` (optimistic concurrency); `SELECT … FOR UPDATE` on bill row at start of write RPCs

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
| `global_stock_id` | bigint | **Live only** — retire into `line_meta.stock_ref` ([BP17](00-gaps.md)) |
| `product_id`, snapshots | | Optional |
| `line_meta` | jsonb | Adapter extras (kg, SKU, `stock_ref`). Charge: `charge_type` (`shipping`, `wrapping`, `print`, …) |

Any module may issue a bill with **only description or charge lines** (fees, AP buckets, service, shipping). Stock lines optional. **Warehouse FIFO runs in the feature module before `issue_bill`**, not inside the kernel. **No `bill_charges` table.**

`charge` lines are commercial amounts on the same paper as stock. Header has no `shipping_charge` / `wrapping_charge` / `print_charge` / `charges_amount`.

**Currency groups on one bill (compose / AR / generic adapters):** lines may use more than one `currency_code` on the same issued bill. Print / UI `GROUP BY currency_code` and `SUM(line_total_amount)` per group for display. Header `total_amount` is the books (BDT) sum of `books_amount`. FX rate lives on the **pay**, not on each line.

**Shipment AP (exception):** cost rows in one **bucket** may use different currencies. `sync_shipment_ap_bills` must **not** issue one mixed-currency AP bill. Group by bucket, then by `currency_code`; **one standard bill per (bucket, currency)**. Plug: `source_type = shipment_cost`, `source_id = shipment id`, `source_key = {bucket}:{currency_code}` (e.g. `freight:GBP`). Keep `ap_kind` = bucket (`material`, `freight`, …) so pays and landed-cost rollups still key off bucket. Each bill’s paper and face amount are **single-currency** for that group.

**Sync vs issue (invariant 1):** While `lifecycle_status = draft`, sync may update line totals. **`issued` standard bills never get silent `total_amount` / txn face updates** — take `lock_global_shipment_costs` → issue; after that, commercial change = CN/DN only. On sync, void only **draft** (or unpaid pre-issue) bills whose `source_key` no longer matches; do not void bills with settlements. Hold advisory lock (§0b) for sync + AP payout on the same shipment. FX for material/freight may aggregate pays across all bills with the same `ap_kind` on that shipment (weighted by paid foreign per currency).

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
| FX | `settlement_currency_code`, `foreign_amount`, `exchange_rate`, `quote_currency_code` | Pair: `exchange_rate` = **quote per 1 settlement**. Default quote `BDT`. Freeze this onto the cashbook line |
| leftover | `unallocated_amount` | Remainder after alloc |
| Idempotency | `idempotency_key` | Optional text; when set **unique** `(tenant_id, idempotency_key)` ([BP25](00-gaps.md)). `post_money_in` / `post_money_out` return existing `pays.id` on duplicate key — no second cashbook line |

Every pay is a transaction you can ask: which point holds (or held) this amount. Ledger rows copy this id. `cashbook_point_id` and `idempotency_key` are on live `pays`; idempotency is enforced in allocation writers via `_kernel_claim_pay_idempotency` ([BP25](00-gaps.md)).

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

### `bill_settlements`

Unified reductions to a bill. Pays, issued credit notes, and custody applications all insert here — **do not** move CN `parent_bill_id` to apply remainder to another bill.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `parent_tenant_id` | bigint | Books |
| `bill_id` | bigint FK `bills` | Bill being reduced |
| `allocator_kind` | text | `pay` \| `credit_note` \| `custody_entry` |
| `allocator_id` | bigint | FK to `pays`, `bills` (CN), or `cashbook_entries` |
| `allocated_txn_amount` | numeric | In bill `txn_currency_code` |
| `allocated_books_amount` | numeric | In books `currency_code` |
| `books_rate_at_alloc` | numeric | **Books per 1 txn** at settlement time ([BP19](00-gaps.md)) |
| `fx_realized_books_delta` | numeric | `allocated_books_amount` − (`allocated_txn_amount` × parent bill `books_exchange_rate` at issue); `0` when txn currency = books |
| `created_at` | timestamptz | Immutable row |

**Balance:** `open_txn` = `txn_total_amount` ± issued notes (txn) − sum(`allocated_txn_amount`); `open_books` likewise. `get_bill_net_balances` uses this model. **COGS / landed cost** still uses pay-weighted rates on shipment; `fx_realized_books_delta` is the **books variance** at bill settlement (treasury / audit), not a second COGS engine.

**Migration ([BP18](00-gaps.md)):** Shipped (`20261031140000_bp18_settlements_cutover`). Pay→bill writes use `_kernel_record_pay_bill_settlement` (insert `bill_settlements`, mirror `pay_allocations`). Readers use settlements; audit [08 §1b](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) stays zero on prod.

### `pay_allocations`

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `payment_id` | bigint FK `pays` | |
| `bill_id` | bigint FK `bills` | One column (drop live `invoice_id` + `global_invoice_id` pair) |
| `amount` | numeric | > 0 books amount |

**Target:** Pay-attached slice of `bill_settlements` during migration, or view over settlements where `allocator_kind=pay`. New alloc RPCs write settlements first.

### `cashbook_accounts`

Tenant **asset** (till/bank books header) vs **profile custody** (liability: customer/vendor advance). One row per `(parent, entity, currency_code)` with strict class.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `account_class` | enum | `tenant_asset` \| `profile_custody` ([BP21](00-gaps.md)) |
| CHECK | | `tenant_asset` ⇒ linked point path; `profile_custody` ⇒ `profile_id` set, no point on entries |
| Unique custody | `(tenant_id, profile_id, currency_code)` | Custody bucketed per currency |

Features do not write the ledger except via kernel pay RPCs. Tenant **BDT** operating book remains books running total. Foreign cash on hand lives on **pots**, not summed with custody liabilities.

### `cashbook_points` (place — not a currency)

Till / safe / bank / fintech under a **tenant** cashbook. Not a stock location. **No currency on the point.** UK cash can hold GBP and BDT as two pots. Profile custody books do not use points in v1.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `parent_tenant_id` | bigint | |
| `cashbook_account_id` | bigint FK `cashbook_accounts` | Tenant **BDT** operating book (header). Pots are extra |
| `code` | text | Unique per account |
| `name` | text | e.g. UK cash, Wise |
| `kind` | enum | `drawer`, `safe`, `bank_counter`, `mobile`, `other` |
| `custodian_membership_id` | bigint | Optional staff |
| `is_active` | boolean | |
| `sort_order` | integer | |

### `cashbook_point_pots` (place × currency)

Running **cash** in one currency at one point. Do **not** store a single FX rate here — money in the same pot can arrive at different rates.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `parent_tenant_id` | bigint | |
| `cashbook_point_id` | bigint FK `cashbook_points` | CASCADE |
| `currency_code` | text | Cash currency (`GBP`, `BDT`, …). Codes from `global_currencies` |
| `amount` | numeric | On-hand in **this** currency. ≥ 0 |
| Unique | `(cashbook_point_id, currency_code)` | One pot per currency per place |

### `books_exchange_rates` (default pick — not posted truth)

Staff pick a rate when recording a pay. Posted cash **copies** the pair onto the ledger line and never looks this table up again.

| Column | Type | Rule |
| :--- | :--- | :--- |
| `id` | bigint PK | |
| `parent_tenant_id` | bigint | |
| `base_currency_code` | text | Always books (`BDT` v1) |
| `quote_currency_code` | text | Foreign (`GBP`) |
| `rate` | numeric | **base per 1 quote** (155.5 BDT per 1 GBP) |
| `rate_date` | timestamptz | When this quote applied |
| `source` | text | `manual` (v1) |

### `cashbook_entries`

| Extra | Type | Rule |
| :--- | :--- | :--- |
| `cashbook_point_id` | bigint FK | Place |
| `cashbook_point_pot_id` | bigint FK `cashbook_point_pots` | Which currency pile moved |
| `amount` | numeric | Cash face (same currency as `currency_code`) |
| `currency_code` | text | Cash currency |
| `quote_currency_code` | text | Books (`BDT`) |
| `exchange_rate` | numeric | **quote per 1 cash** (BDT per 1 GBP) |
| `base_amount` | numeric | Frozen books (`amount` × rate) |
| `rate_date` | date | When that pair was used |

Pay in / pay out **must** pass a point when tenant cash moves. **Append-only** `cashbook_entries` (`INSERT` only; reversals = offsetting insert). `cashbook_point_pots.amount` updated **only** by `AFTER INSERT` trigger on entries — writers do not `UPDATE` pots directly ([BP22](00-gaps.md)). `transfer_cashbook_point` locks pots in deterministic order (`ORDER BY cashbook_point_id, currency_code`) to avoid deadlocks. Collect/AP still often post BDT-only ([BP15](00-gaps.md) / [BP16](00-gaps.md)).

---

## 1b. Read projections (CQRS)

Kernel tables stay private to money RPCs. Reporting and desks may `SELECT` **views** as part of the public read contract ([BP23](00-gaps.md)).

### `v_kernel_bill_summaries`

| Column | Rule |
| :--- | :--- |
| `bill_id` | PK |
| `parent_tenant_id` | |
| `source_type`, `source_id`, `source_key` | Adapter plug |
| `lifecycle_status` | `draft` \| `issued` \| `voided` |
| `settlement_status` | Derived |
| `txn_currency_code`, `txn_total_amount`, `open_txn` | Face currency |
| `currency_code`, `total_amount`, `open_books` | Books |
| `due_date` | |
| `from_profile_id`, `to_profile_id` | |

Grant `SELECT` on views to `authenticated` (with RLS mirroring tenant scope). Do not grant direct `SELECT` on `bills` for feature modules.

**Pagination ([BP23](00-gaps.md)):** Desks list via **keyset** `(parent_tenant_id, bill_id DESC)` (or `document_date`, `bill_id`) — no large `OFFSET` on busy tenants. Plain SQL view v1; optional **materialized** snapshot later with explicit refresh policy (nightly or post-batch) — not required for v1.

**Read-your-writes:** After collect/payout, UI must refresh detail via `get_bill_net_balances` (or invalidate list query). Do not trust list `settlement_status` alone immediately after a write.

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
| Shipment AP | `shipment_cost` | shipment id | `{bucket}:{currency_code}` | vendor/cargo | tenant. One bill per **bucket × currency**; never mix currencies on one shipment AP bill |
| Shop / dropship | `shop_order` | order id | optional | tenant | merchant |
| Delivery close | `delivery_close` | paper id | — | tenant | customer |
| After-sales money | parent source copied | | | same | same | via `create_bill_adjustment` |

**Kernel RPCs (target names)**

| RPC | Job |
| :--- | :--- |
| `upsert_draft_bill` | from/to, lines, source, dates, currency, `settlement_kind` |
| `update_draft_bill` | edit draft (wrapper → `update_sales_invoice_from_payload`) |
| `issue_bill` / `void_bill` | paper; no warehouse |
| `issue_wholesale_bill` / `issue_retail_bill` | FIFO wholesale / retail issue (wrappers) |
| `get_bill_detail_bundle` | desk read: bill + history + balances + adjustments |
| `list_bills_desk_page` | desk list: keyset on `bills.id`, slim row JSON |
| `create_bill_adjustment` | CN/DN child |
| pay in / pay out + alloc | writes `bill_settlements` |
| `apply_settlement_to_bill` | custody / CN / leftover → bill (live alias `apply_leftover_to_bill`) |
| `reverse_pay` | unwind pay settlements; lifecycle unchanged |
| `transfer_cashbook_point` | move cash between two tenant points (same currency v1); append-only ledger; no `pays` row |
| `bounce_cheque_instrument` | one CHEQUE slice: whole pay if single instrument; else partial (LIFO settlement unwind, pay stays open) |
| `get_bill_net_balances` | face ± notes − settlements |
| `list_bills_for_source` | all documents for one adapter row |
| `v_kernel_bill_summaries` | paginated list / join for desks |

**Point transfer (BP15‑t):** v1 is **same currency only** — debit `from` pot and credit `to` pot in one logical transfer (`source_type = point_transfer`, shared transfer id). Both points’ pots are locked in ascending `cashbook_point_id` order before balance reads. Grant: `collect_payment`.

**Cheque bounce partial (WA13‑p):** when a pay has **more than one** active instrument, bouncing one CHEQUE reverses ledger for that instrument’s **books** amount only, unwinds `bill_settlements` **newest first (LIFO)** up to that cap (full settlement rows only), reduces `pays.amount`, and does **not** set `voided_at`. Single-instrument pays still call `reverse_pay` (whole receipt).

---

## 4. Live → target map

| Live `bills` | Target |
| :--- | :--- |
| `profile_id` | One of from/to (the counterparty). Fill the other with tenant profile |
| `invoice_type = ap` | from = vendor/cargo, to = tenant |
| `invoice_type` wholesale/retail/dropship | from = tenant, to = customer/shop |
| `invoice_no` / `invoice_status` | `document_no` / `lifecycle_status` |
| `payment_status` | `settlement_status` (rename / map values) |
| (none) | `txn_currency_code`, `txn_total_amount`, `books_exchange_rate` ([BP19](00-gaps.md)) |
| `bill_lines.global_stock_id` | `line_meta.stock_ref` ([BP17](00-gaps.md)) |
| `pay_allocations` only | `bill_settlements` + optional pay slice ([BP18](00-gaps.md)) |
| `ap_shipment_id` + `ap_kind` | `source_type=shipment_cost`, `source_id`, `source_key` |
| `shop_order_id` | `source_type=shop_order`, `source_id` |
| `channel_meta.delivery_kind` | `settlement_kind` (`take` \| `condition`) |
| `recipient_*` | not kernel; adapter meta |
| `bill_lines.invoice_id` | `bill_id` |
| `bill_charges` + header charge columns | `bill_lines` with `line_kind = charge`; then **drop** `bill_charges` |
| `pay_allocations.global_invoice_id` | `bill_id` |

Migrate: add from/to + source columns, backfill, adapters write them, then drop special FKs.
