# Investor capital — data model

Live SQL: `investors`, `investor_transactions` (as-built journal — target removal IC4), `shipment_investments` in `supabase/schemas/` (procurement tables). Wallet lines: [wallet 02](../wallet/02-data-model.md). Staff app UI and investor portal read the same tables (no UI-only tables). Do not paste full `CREATE` here.

## Three entities + wallet

| Table / account | Owns | Does not own |
| :--- | :--- | :--- |
| `investors` | Name, address, phone, email, notes, `is_active`, `currency_code` | Cash balances, login secrets |
| `memberships` | `role = investor`, `investor_id`, email, tenant | Capital math |
| `shipment_investments` | `investor_id`, `global_shipment_id`, `invested_amount`, `cost_share_pct`, profit fields, `status` | Ledger lines |
| Wallet `entity_type = investor` | Available / pending buckets per `investor_id` | Shipment % |

```text
tenants
  └── investors (identity)
        ├── memberships (portal login)
        ├── universal_wallet_ledger (cash book)
        └── shipment_investments → global_shipments
```

## `investors` (identity)

| Column (concept) | Notes |
| :--- | :--- |
| `tenant_id` | Parent company |
| `name`, `phone`, `email`, `address`, `notes` | Contact |
| `is_active`, `currency_code` | Desk flags |

No `total_deposited` / `current_balance` on the row in the target model.

## `shipment_investments` (batch share)

| Column (concept) | Notes |
| :--- | :--- |
| `investor_id`, `global_shipment_id` | One row per partner per shipment |
| `invested_amount` | Capital attributed to this batch |
| `cost_share_pct` | Share of cost/profit (0–100 in live schema) |
| `allocated_cost`, `computed_profit`, `profit_status` | Filled by refresh / P&amp;L RPCs |
| `status` | e.g. active |

Unique: one investor per shipment.

## Money (wallet)

One ledger account per `(parent_tenant_id, entity_type = investor, entity_id = investor_id, currency)`.

| Event | Tenant wallet | Investor wallet |
| :--- | :--- | :--- |
| Capital in | Credit (cash received) | Credit (liability to partner) |
| Payout paid | Debit (cash out) | Debit (reduce liability) |
| Realized profit (once) | — | Credit `pending` (idempotent per shipment) |

Only `record_ledger_transaction`. Not a receipt (`global_payments`).

## RLS (intent)

| Actor | `investors` | `shipment_investments` | Wallet |
| :--- | :--- | :--- | :--- |
| Staff | Manage parent tenant | Manage parent tenant | Staff treasury rules |
| Partner | `auth_investor_id() = id` | Same investor id | Own investor entity only |

Helper: `auth_investor_id()` from active membership `role = investor` + matching email.

## As-built note (IC4)

`investor_transactions` still exists and mirrors desk deposits/payouts. Spec target: wallet lines are source of truth; journal table retired in a later slice.
