# `record_ledger_transaction` — System RPC Caller Migration

Upgrade every **domain writer** that posts to the universal wallet so it uses **parent books** + **operating desk**, not child `tenant_id` alone.

**Parent plan:** [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](./WALLET_PARENT_BOOKS_IMPLEMENTATION.md) (P0 → P1 → P2/P3)  
**Target model:** [`WALLET.md`](./WALLET.md) §1.1–1.4

---

## Why

Today most writers pass `p_tenant_id => child_id` (e.g. Dropshipping `11`). The wallet UI reads **parent book**. After P0 backfill, old rows are readable; **new** writes must use the new parameters so balances land on the book the UI queries.

---

## Dependency order

| Step | Work |
| :--- | :--- |
| **P0** | Add `parent_tenant_id`, `operating_tenant_id`; backfill; merge child tenant cash pools |
| **P1** | Upgrade `record_ledger_transaction` + read RPCs (`get_wallet_account_balances`, …) |
| **P2** | Sales invoice + shop order writers (this doc §3–4) |
| **P3** | Procurement + investor writers (§5–6) |
| **P5b** | Replace direct `record_ledger_transaction` from wallet UI with `record_wallet_manual_transaction_for_staff` |

Ship **P0 + P1 + all P2/P3 callers in one migration batch** (or immediately after P1). Do not leave writers on `p_tenant_id` alias while UI reads parent.

---

## P1 — Core engine change

**File:** `supabase/schemas/public.sql` — `record_ledger_transaction`

### New signature (recommended)

```sql
record_ledger_transaction(
  p_parent_tenant_id     bigint,
  p_operating_tenant_id  bigint,
  p_entity_type          text,
  p_entity_id            bigint,
  p_type                 text,
  p_amount               numeric,
  p_currency_code        text default 'BDT',
  p_exchange_rate        numeric default 1.000000,
  p_source_type          text default 'adjustment',
  p_source_id            text default null,
  p_metadata             jsonb default '{}',
  p_target_bucket        text default 'available',
  p_allow_overdraft      boolean default false
)
```

### Internal behaviour

1. **Upsert** `wallet_accounts` on `(parent_tenant_id, entity_type, entity_id, currency_code)` — not `tenant_id`.
2. **Insert** `universal_wallet_ledger` with `parent_tenant_id`, `operating_tenant_id`, same entity columns.
3. **Tenant cash:** when `p_entity_type = 'tenant'`, require `p_entity_id = p_parent_tenant_id` (raise or coerce with logged notice during transition).
4. **Return JSON** includes `parent_tenant_id`, `operating_tenant_id` (keep `tenant_id` in JSON one release if clients still read it → map to `parent_tenant_id`).

### Optional backward-compat overload (one release)

```sql
-- Deprecated: maps p_tenant_id → parent only, operating = parent
record_ledger_transaction(p_tenant_id bigint, ...) 
```

Prefer **no alias** if P2/P3 ship in the same deploy.

### Same-file siblings (P1)

| Function | Change |
| :--- | :--- |
| `get_wallet_account_balances` | Filter `wallet_accounts.parent_tenant_id`; param `p_parent_tenant_id` |
| `get_wallet_dashboard_summary` | Aggregate on `parent_tenant_id` |
| `get_wallet_entity_statement` | Ledger filter `parent_tenant_id`; optional `p_operating_tenant_id` |
| `transfer_wallet_balance` | Account key + ledger legs use `parent_tenant_id`; pass `operating_tenant_id` on ledger rows |

---

## Standard caller pattern

Add at top of each writer after loading the domain row:

```sql
v_books_id := public.resolve_parent_tenant_id(v_operating_id);
-- or from invoice: v_books_id := coalesce(v_invoice.parent_tenant_id, public.resolve_parent_tenant_id(v_invoice.tenant_id));
```

| Source row | `v_operating_id` | `v_books_id` |
| :--- | :--- | :--- |
| `shop_orders` | `v_order.tenant_id` | `resolve_parent_tenant_id(v_order.tenant_id)` |
| `global_invoices` | `coalesce(issued_by_tenant_id, tenant_id)` | `coalesce(parent_tenant_id, resolve_parent(tenant_id))` |
| `global_shipments` | `coalesce(assigned_child_tenant_id, parent_tenant_id)` | `parent_tenant_id` |
| `billing_profiles` / vendor RPC `p_tenant_id` | `p_tenant_id` (desk param) | `resolve_parent_tenant_id(p_tenant_id)` |
| Investor RPC `p_tenant_id` | `p_tenant_id` | `resolve_parent_tenant_id(p_tenant_id)` |

### `perform` template

```sql
perform public.record_ledger_transaction(
  p_parent_tenant_id    => v_books_id,
  p_operating_tenant_id => v_operating_id,
  p_entity_type         => 'tenant',
  p_entity_id           => v_books_id,   -- company cash pool
  p_type                => 'credit',
  p_amount              => v_amount,
  ...
);
```

**Courier / customer / vendor legs:** same `v_books_id` + `v_operating_id`; `entity_id` unchanged (courier `wallet_entity_id`, customer `billing_profiles.id`, etc.).

### Idempotency / lookup queries

Replace:

```sql
where tenant_id = v_order.tenant_id
```

With:

```sql
where parent_tenant_id = v_books_id
  and operating_tenant_id = v_operating_id   -- when scoping per order desk
```

For idempotency keyed only by `source_type` + `source_id` + metadata, still filter `parent_tenant_id = v_books_id` so child/parent duplicate rows cannot coexist.

### `wallet_accounts` upserts in callers

Any `insert into wallet_accounts ... on conflict (tenant_id, ...)` → conflict on `(parent_tenant_id, entity_type, entity_id, currency_code)` after P0.

---

## P2 — Sales invoice writers

**File:** `supabase/schemas/sales_invoice/03_rpcs.sql`

| RPC | Ledger legs | Today `p_tenant_id` | After migration |
| :--- | :--- | :--- | :--- |
| `apply_global_invoice_settlement_discount` | Tenant debit (write-off) | `v_invoice.tenant_id` | Books + operating from invoice; tenant `entity_id = v_books_id` |
| `create_billing_profile_payment_with_allocations` | Tenant credit + customer credit | `p_tenant_id` | Books = resolve(`p_tenant_id`); operating = `p_tenant_id` |
| `dispense_middleman_payout_from_tenant` | Tenant debit + customer debit | `p_tenant_id` | Same; FIFO helper reads UWL with `parent_tenant_id` |
| `post_sales_invoice` | Retail account: customer debit `invoice_billed` | `v_eff_tenant_id` | Books = `coalesce(parent, resolve(tenant))`; operating = `issued_by ?? tenant` |
| `record_recipient_invoice_collection` | Tenant credit (cash in) | `v_invoice.tenant_id` | Invoice books + operating |
| `process_wholesale_invoice_return` | Customer credit (`wallet_credit`); tenant debit (`payout`) | `v_eff_tenant_id` / `v_parent_id` | Align tenant leg `entity_id` to `v_books_id`; customer leg unchanged |
| `collect_wholesale_invoice_payment` | Tenant credit (cash); customer debit (store credit) | `coalesce(parent, tenant)` | Add `operating_tenant_id`; tenant `entity_id = v_books_id` |

**Related (no `record_ledger` in current schema — sync from latest migration when touching dropship):**

| RPC | Notes |
| :--- | :--- |
| `ensure_dropship_invoice_billed_entry` | Latest migration: **no-op** (dropship B2B does not bill customer wallet). If re-enabled, use shop order books + `source_id = order_id`. |
| `ensure_dropship_tenant_b2b_invoice_at_delivered` | Calls ensure + issue path; no direct ledger in schema stub |

**Invoice field helpers:**

```sql
v_operating_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
v_books_id     := coalesce(v_invoice.parent_tenant_id, public.resolve_parent_tenant_id(v_invoice.tenant_id));
```

---

## P2 — Shop order / dropship writers

**File:** `supabase/schemas/shop_order/03_rpcs.sql`

| RPC | `record_ledger` calls | Tenant `entity_id` today | After |
| :--- | :---: | :--- | :--- |
| `confirm_dropship_delivered_costing` | 1 (courier COD credit) | — | Books + operating from order |
| `finalize_dropship_return` | 9 (return reversals, fees) | Child id on tenant legs | Tenant legs → `v_books_id`; all UWL reads → `parent_tenant_id` |
| `process_dropship_courier_remittance_uwl` | 2–3 (courier debit ×2, tenant credit) | Child id | Tenant credit `entity_id = v_books_id`; idempotency on `parent_tenant_id` |
| `record_dropship_courier_remittance` | 1 (`invoice_collection` on customer) + metadata `update` | Child | Customer leg + `update universal_wallet_ledger` where clauses |

**Migration-only RPCs (not in `03_rpcs.sql` — patch via new migration + schema sync):**

| RPC | Ledger |
| :--- | :--- |
| `record_dropship_courier_bank_transfer` | Delegates to `process_dropship_courier_remittance_uwl` |

**Read-only / delete (no `record_ledger` — still update `tenant_id` filters):**

| RPC | Touch |
| :--- | :--- |
| `advance_dropship_order_status` | `delete from universal_wallet_ledger where tenant_id = …` → `parent_tenant_id` + `operating_tenant_id` |
| `apply_dropship_payout_settlement_fifo` | UWL sum for `dropship_profit` |
| Dropship wallet audit RPCs (`audit_dropship_wallet_health`, etc.) | All `u.tenant_id` predicates |

**Shop order helpers:**

```sql
v_operating_id := v_order.tenant_id;
v_books_id     := public.resolve_parent_tenant_id(v_order.tenant_id);
```

---

## P3 — Procurement writers

**File:** `supabase/schemas/procurement/03_rpcs.sql`

Most shipment paths already pass `v_ship.parent_tenant_id` as `p_tenant_id`. **Add `operating_tenant_id`** on every ledger line.

| RPC | Legs | Today | After |
| :--- | :--- | :--- | :--- |
| `pay_settle_shipment_costs` | Payee debit + tenant debit (cash/wallet); credit path | `parent_tenant_id` | `p_parent` = ship.parent; `p_operating` = `coalesce(assigned_child_tenant_id, parent)`; tenant `entity_id` already parent |
| `settle_shipment_payee` | `pay` / `record_credit` / `use_credit` | `parent_tenant_id` | Same operating rule |
| `return_shipment_to_vendor` | Tenant credit + vendor debit (cash_refund) | `parent_tenant_id` | + operating |
| `refresh_shipment_investor_profits` | Investor pending profit credit | `parent_tenant_id` in exists check | `parent_tenant_id` + operating |
| `record_vendor_grn_payable` | Vendor credit (AP) | `p_tenant_id` param | Books + operating from param |
| `record_vendor_payment_outflow` | Vendor debit + tenant debit | `p_tenant_id` | Tenant `entity_id = v_books_id` |

**Shipment helpers:**

```sql
v_books_id     := v_ship.parent_tenant_id;
v_operating_id := coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id);
```

---

## P3 — Investor writers

**File:** `supabase/schemas/public.sql`

| RPC | Legs | After |
| :--- | :--- | :--- |
| `record_investor_capital_in` | Tenant credit + investor credit | Books + operating from `p_tenant_id`; tenant `entity_id = v_books_id` |
| `record_investor_withdrawal_paid` | Investor debit + tenant debit | Same |

`record_investor_capital_adjustment` — no UWL today; no change.

**Retire (do not migrate):** `dispense_middleman_payout` — broken zombie; drop per [`WALLET_LEGACY_RETIREMENT.md`](./WALLET_LEGACY_RETIREMENT.md). Keep `dispense_middleman_payout_from_tenant`.

---

## Frontend legacy callers (until P5b)

Replace after `record_wallet_manual_transaction_for_staff` ships:

| File | Current RPC |
| :--- | :--- |
| `web/src/modules/wallet/repositories/walletRepository.ts` | `record_ledger_transaction` |
| `WalletDepositModal.vue`, `WalletWithdrawModal.vue` | via repository |
| `UniversalWalletPage.vue` | direct `recordTransaction` for some actions |

Interim: pass `p_parent_tenant_id` + `p_operating_tenant_id` from `walletBooksTenantId()` + selected tenant id.

---

## Master checklist (system RPCs)

### P1 core

- [ ] `record_ledger_transaction` — parent + operating params
- [ ] `get_wallet_account_balances`
- [ ] `get_wallet_dashboard_summary`
- [ ] `get_wallet_entity_statement`
- [ ] `transfer_wallet_balance`

### P2 sales invoice (7 RPCs)

- [ ] `apply_global_invoice_settlement_discount`
- [ ] `create_billing_profile_payment_with_allocations`
- [ ] `dispense_middleman_payout_from_tenant`
- [ ] `post_sales_invoice`
- [ ] `record_recipient_invoice_collection`
- [ ] `process_wholesale_invoice_return`
- [ ] `collect_wholesale_invoice_payment`

### P2 shop order (4 + helpers)

- [ ] `confirm_dropship_delivered_costing`
- [ ] `finalize_dropship_return` (+ all UWL reads in function)
- [ ] `process_dropship_courier_remittance_uwl`
- [ ] `record_dropship_courier_remittance` (+ metadata update)
- [ ] `record_dropship_courier_bank_transfer` (migration RPC)
- [ ] `advance_dropship_order_status` (UWL delete)
- [ ] `apply_dropship_payout_settlement_fifo` (UWL read)

### P3 procurement (6)

- [ ] `pay_settle_shipment_costs`
- [ ] `settle_shipment_payee`
- [ ] `return_shipment_to_vendor`
- [ ] `refresh_shipment_investor_profits`
- [ ] `record_vendor_grn_payable`
- [ ] `record_vendor_payment_outflow`

### P3 investor (2)

- [ ] `record_investor_capital_in`
- [ ] `record_investor_withdrawal_paid`

### Verify

- [ ] Order #37 balances visible on parent book after backfill + writer fix
- [ ] Wholesale invoice collect → tenant pool on parent `entity_id`
- [ ] Dropship deliver → remit → customer `invoice_collection` on parent book
- [ ] Shipment settle → tenant cash debits parent pool
- [ ] `pnpm run backend:reset`

---

## Grep maintenance

After edits, repo should have **zero** `record_ledger_transaction(` calls still passing only `p_tenant_id` without parent/operating (except deprecated overload body):

```bash
rg 'record_ledger_transaction' supabase/schemas --glob '*.sql'
rg 'tenant_id = v_order\.tenant_id' supabase/schemas/shop_order
rg 'on conflict \(tenant_id, entity_type' supabase/schemas
```
