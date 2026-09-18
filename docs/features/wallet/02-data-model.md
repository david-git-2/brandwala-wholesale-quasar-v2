# Wallet & receipts — data model

Live SQL: ledger in `public.sql` (wallet schema stub). Payments today: `global_payments`, `invoice_payments`. Target below. Gaps: [00-gaps](00-gaps.md).

```text
RECEIPT (money in)
    ├─ allocations → sales_invoices (up to total_amount)
    └─ remainder → record_ledger_transaction
         tenant cash | customer store credit | courier | merchant payable

PAYOUT (money out) → ledger + tenant cash
```

COD **face** is not a receipt row. It lives on `shop_orders` (and invoice `channel_meta` snapshot).

---

## Receipt (target; one table)

Reuse/extend `global_payments` (or rename in a later split). Essentials:

| Column | Meaning |
| :--- | :--- |
| `parent_tenant_id`, `operating_tenant_id` | Books vs desk |
| `source` | `customer_cash` \| `bank` \| `store_credit` \| `courier_remittance` |
| `amount` | Money that hit you (dropship = **net remitted**, not COD face) |
| `entity_type` / `entity_id` | Payer: billing profile, courier, … |
| `reference`, `bank_trx_id`, `received_on` | Remittance / voucher ref |
| `shop_order_id` | Optional; dropship remittance |

Do not store `cod_collect_amount` as `amount`.

---

## Allocation (target)

Existing `invoice_payments`: receipt → invoice, `amount` ≤ due. Sum of allocations ≤ receipt `amount`. Updates invoice `paid_amount` / `due_amount` / `payment_status` only.

Dropship: allocate **min(net remittance, merchant invoice due)**. Remainder → merchant (and courier fee already netted out of receipt, or a fee line on the receipt — not extra sales).

---

## Ledger (as-built intent)

One account per `(parent_tenant_id, entity_type, entity_id, currency)`. Lines only via `record_ledger_transaction`.

| Entity | Typical use |
| :--- | :--- |
| `tenant` | Operating cash (parent pool) |
| `customer` | Store credit; dropship merchant payable (`billing_profile`) |
| `courier` | Optional in-transit / fee clearing — **not** a second COD sales book |
| `vendor` / `cargo` / `investor` | Other books; investor **no** withdraw |

`source_type` on a ledger line should point at the **receipt** (or payout), not a parallel “delivered_costing” purpose for the same cash.

---

## Payout

Debit merchant wallet, debit tenant cash. Not an invoice allocation. Not investor portal.

---

## Report split

| Sum | Source |
| :--- | :--- |
| Tenant sales | Issued invoices (`total_amount`) |
| Cash in | Receipts |
| Courier vs bank | Receipts with `source = courier_remittance` |
| What we owe resellers | Merchant wallet / ledger |

Never treat receipt `amount` as sales. Never `SUM(COD face)` as revenue.
