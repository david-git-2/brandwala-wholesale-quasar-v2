# Bills — spec

## Status

| | |
| :--- | :--- |
| **What** | Obligation paper: issue, lines, credit notes, write-off. **No** live cash balance. |
| **SQL** | `supabase/schemas/money_kernel_v2/` — schema `money_kernel` (shared with money until physical split) |
| **UI** | `web/src/modules/sales_invoice/` · AP desks |
| **Not here** | Cash bundles, `rpc_pay_bills` cash legs — [money](../money/spec.md), [bridge](../money_bill_bridge/spec.md) |
| **System map** | [bridge § Atlas](../money_bill_bridge/spec.md#atlas) |

**Paper truth:** `money_kernel.bills.due_amount`, `paid_amount`, `written_off_amount`, `status`. Cash truth is [money](../money/spec.md).

**Target:** no **`bill_events`** table — history comes from `bills` + `bill_settlements` (+ linked `pays`). **Live SQL** still has `bill_events` / `v_bill_events` until cutover migration.

---

## What it is

A **bill** is who owes whom how much, in which currency, with frozen lines after issue. **Settlements** record satisfaction:

| `settlement_kind` | Meaning |
| :--- | :--- |
| `pay` | Cash via `money_kernel.pays` — orchestrated by [bridge](../money_bill_bridge/spec.md) |
| `document` | Credit note applied onto another bill — **no** cash |

**Parties:** `from_profile_id` = debtor, `to_profile_id` = creditor. **AR:** from = customer, to = **tenant self-profile**. **AP:** from = tenant self-profile, to = vendor (`cashbook_enabled=false` — no vendor wallet; obligation stays on the bill).

**Currency:** `currency_code` / target `currency_id` → `public.global_currencies` ([money spec](../money/spec.md)) — not `money_kernel.currencies` at cutover.

Modules call **`public.rpc_*` only**. No client DML on kernel tables.

---

## Data model (`money_kernel`)

```text
profiles + global_currencies → bills → bill_lines
bills → bill_settlements → (pay → pays) | (document → bills CN)
```

Composite FKs `(tenant_id, id)`. DDL: [`21_money_kernel_tables.sql`](../../../supabase/schemas/money_kernel_v2/21_money_kernel_tables.sql).

---

## What each table does

| Table | Does what |
| :--- | :--- |
| `public.profiles` | Names the debtor and creditor on every bill; not stored balances. |
| `public.global_currencies` | **Target** — which currencies bills may use (`symbol` for UI). |
| `bill_kind_registry` | Product catalog of bill types — controls numbering, meta rules, and whether cash pay is allowed. |
| `invoice_no_counters` | Hands out the next invoice number per tenant + prefix at issue time. |
| `bills` | **The obligation** — who owes whom, how much total / paid / due / written off, status, link back to shipment/order/etc. |
| `bill_lines` | Line items on the bill; frozen when the bill is issued. |
| `bill_settlements` | **Proof of satisfaction** — also the audit trail for pay/CN apply (amount, time, linked pay). |
| `money_outbox` | Optional machine feed for async consumers (not audit spine). |
| `money_kernel.pays` | Cash movement header when a settlement is `pay` — owned by [money](../money/spec.md); bills only hold the FK link. |

---

**Column DDL:** [`21_money_kernel_tables.sql`](../../../supabase/schemas/money_kernel_v2/21_money_kernel_tables.sql). Currency FK → `public.global_currencies` ([money](../money/spec.md)).

## Locked decisions (paper)

| Topic | Rule |
| :--- | :--- |
| Create / issue | `rpc_create_bill` → always `draft`; issue via `auto_issue` or `rpc_issue_bill`; `total_amount > 0` at issue |
| Invoice number | Null on draft; allocated at issue only (`rpc_allocate_invoice_no` internal) |
| Credit note | Bill with swapped parties vs parent; apply via **`rpc_apply_document_settlement`** only — never `rpc_pay_*` on CN |
| CN apply | Target must share party pair (`target.from = CN.to`, `target.to = CN.from`); partial OK |
| Debit note | Normal bill; cash pay only |
| Document idempotency | `bill_settlements.idempotency_key` unique per tenant when set |
| Write-off | `rpc_write_off_bill` on remaining due; no write-off on CN (void or apply) |
| Void bill | Refuse if bill sits on **multi-bill** pays — void pays first ([bridge](../money_bill_bridge/spec.md)) |
| Lines | Immutable after issue (T8); totals freeze once any settlement exists |
| FX on bill pay | Payment pay: bill + cash share one currency; `exchange_rate=1`; FX first via `rpc_transfer_p2p` ([money](../money/spec.md)) |
| Feature parent | `source_entity` + `source_id` + `source_key` on bill row |

---

## Bill RPCs (this pack)

| RPC | Job |
| :--- | :--- |
| `rpc_create_bill` | Draft + lines payload; optional `auto_issue` |
| `rpc_issue_bill` | Draft → issued; lines frozen |
| `rpc_void_bill` | Void bill (settlement guards) |
| `rpc_write_off_bill` | Forgive remaining due |
| `rpc_apply_document_settlement` | Apply credit note to target bill |
| `rpc_void_document_settlement` | Undo one document apply |
| `rpc_allocate_invoice_no` | **Internal** — only from issue |

**Read:** `rpc_get_bill`, `rpc_query_bills` (cursor, `p_source_*` filters), `rpc_list_bill_kinds`.

**Views:** `v_bills_unified`, `v_bill_lines_unified` (drop `v_bill_events` with `bill_events` table).

Cash RPCs (`rpc_deposit`, `rpc_pay_bills`, …): [money](../money/spec.md) · [bridge](../money_bill_bridge/spec.md).

---

## Source plug (modules)

`rpc_create_bill`: `source_entity`, `source_type`, `source_id`, `source_key` (parent + discriminator). List: `rpc_query_bills` `p_source_*`. No DML; no `rpc_allocate_invoice_no` from features.

**Delivery paper AR:** `apply_delivery_paper_outcome` (take / condition) calls **`rpc_create_bill`** with `kind = sales_invoice_wholesale`, stock lines, `source_key` `delivery_paper:{id}:take|condition` (shop order: `source_entity = public.shop_orders`; PBC: `public.delivery_paper`). Draft only; issue via **`rpc_issue_bill`** / desk after stock commit.

## Shipment cost AP (Option A) {#shipment-cost-ap}

One kernel bill per **bucket × currency** (`source_key` e.g. `material:GBP`). Costs tab → draft/issue on kernel; retire `global_shipment_cost_entries` after cutover. Wiring: [procurement spec](../procurement_stock/spec.md) · PS35.

---

## Security (summary)

RPC `EXECUTE` via `assert_kernel_money_access`; no client DML on kernel bill tables. Grep `money_kernel_v2/` for grants.

---

## Invariants (paper)

| Id | Rule |
| :--- | :--- |
| I8 | `bills.kind` in registry |
| I9 | `total = sum(lines)` at issue |
| I10–I11 | Non-negative; `paid+due+written_off=total` unless voided |
| I12–I13 | Structural cols / totals frozen after issue or settle |
| I14 | `paid` / `due` / `status` from triggers + RPCs |
| I17 | Document apply: source remaining ≥ alloc; target due ≥ alloc |
| I18 | Both party profiles required to issue |
| I25 | CN parties = swap of parent |
| I33 | Σ non-voided CN totals ≤ parent total |
| I34 | Lines immutable after issue |

Cash invariants (I5, I7, …): [money/spec.md](../money/spec.md).

---

**History / outbox:** settlements + header on `rpc_get_bill`; optional `money_outbox` poll by `xid` (not audit spine).

---

## Gaps {#gaps}

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| B1 | not_built | Shipment AP on kernel bills | Adjunct Option A in this spec | Costs tab + drop `global_shipment_cost_entries` |
| B2 | shipped | Desk list kernel-only | `list_bills_desk_page` → `money_kernel.bills` only | bills_pays/spec.md |
| B3 | sql_split | Logical bills owner | DDL in `money_kernel_v2` | Future schema split |
| B4 | cutover | Drop `bill_events` | Table + T5/T6 triggers + `v_bill_events` | Migration; remove event includes from `rpc_get_bill` |

---

## Legacy cutover {#legacy-cutover}

**Do not drop** until bills_pays/spec.md blockers clear.

| Legacy | v2 |
| :--- | :--- |
| `public.bills` | `money_kernel.bills` |
| `public.bill_lines` / `global_invoice_items` | `money_kernel.bill_lines` |
| `pay_allocations` | `bill_settlements` |
| `post_money_in` / `out` | `rpc_deposit` / `rpc_withdraw` |
| `upsert_draft_bill` / `issue_bill` | `rpc_create_bill` / `rpc_issue_bill` |
| `cashbook_entries` | pays + bundles ([money](../money/spec.md)) |
| `sales_invoice_counters` | `invoice_no_counters` |
| `bill_events` | **Drop** — use settlements + bill header |

**Backfill:** [07-backfill-cutover.sql](07-backfill-cutover.sql).

---

## PR checklist

- [ ] Bill paths use kernel RPCs only (no direct DML)
- [ ] CN never paid with cash RPCs
- [ ] Source plug set for feature-originated bills
- [ ] Bridge tests if settlement rules change — [bridge/spec.md § Test matrix](../money_bill_bridge/spec.md#test-matrix)
