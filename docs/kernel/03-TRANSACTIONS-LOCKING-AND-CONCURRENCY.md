# Transactions, locking, and concurrency

**Job:** Transaction safety for money RPCs — isolation, row locks, deadlock avoidance, idempotency, and DB guards against negative balances and over-allocation.

Cross-ref: [01-SYSTEM-INVARIANTS](01-SYSTEM-INVARIANTS.md) · Live writers in `supabase/schemas/bills_pays/03_rpcs.sql`.

---

## Isolation level

| Setting | Choice |
| :--- | :--- |
| Default | **READ COMMITTED** (Postgres / Supabase PostgREST — no `SET TRANSACTION` in kernel today) |
| Why | Short `SECURITY DEFINER` RPC transactions; correctness from **row locks** + checks at write time, not serializable reads across the whole cart/session |

Do not rely on a stale read of `due_amount` or ATP outside a single RPC transaction.

---

## Pessimistic locking (`SELECT … FOR UPDATE`)

Used inside kernel RPCs on rows that must not change mid-flight:

| Resource | Typical RPC |
| :--- | :--- |
| `bills` (header) | Issue, void, delete order, AP payout prep |
| `global_stocks` | `issue_sales_invoice` line deduct, dropship pick/release, wholesale issue |
| `global_shipments` | Shipment settlement / cost lock paths |

**Rule:** Lock **before** read-modify-write on quantities or issued totals. ATP helpers (`global_stock_atp_qty`) are stable snapshots — concurrent carts can still race unless the **same** RPC locks the stock row (shop add-to-cart today checks ATP without `FOR UPDATE`; see [07-TDD](07-TDD-AND-VERIFICATION-SUITE.md)).

---

## Lock ordering (deadlock prevention)

When one RPC touches **multiple** bill or stock rows:

1. Collect ids to lock.
2. **`ORDER BY id ASC`**.
3. `SELECT … FOR UPDATE` in that order.

Two pays allocating overlapping bills in opposite order → Postgres deadlock; ascending id order is the project convention for new multi-row kernel code.

Single-bill collect paths lock one bill header first — low deadlock risk.

---

## Idempotent payment ingestion (target)

| Mechanism | Status |
| :--- | :--- |
| Unique `(parent_tenant_id, source_type, source_id, source_key)` on **standard** bills | Target ([kernel-schema](../features/bills_pays/kernel-schema.md)); partial live |
| Pay idempotency key (`p_idempotency_key` → unique on `pays`) | **Not built** ([BP12](../features/bills_pays/00-gaps.md)) — retries may double-post until added |
| Remittance / shop order linking | Live: `p_shop_order_id` on collect; adapter must not call pay writer twice for same settlement event |

New `kernel_post_payment` should accept optional `p_idempotency_key` and `ON CONFLICT` return existing `pays`.

---

## Constraints and RPC guards

| Guard | Where |
| :--- | :--- |
| `pay_allocations.amount > 0` | CHECK on table |
| `cashbook_entries.amount >= 0`, `exchange_rate > 0` | CHECK |
| `cashbook_point_pots.amount >= 0` | CHECK (target pot balance) |
| Alloc sum ≤ pay amount | `post_customer_receipt_with_allocations`, `post_ap_payout_with_allocations` |
| Alloc sum ≤ bill net due | Writers call `get_bill_net_balances` or equivalent before insert |
| Issue with insufficient stock | `raise exception 'insufficient ATP…'` / stock qty checks after `FOR UPDATE` |
| Void issued with pays | `raise exception 'cannot void a paid…'` |

Over-allocation must **fail the transaction** — no partial alloc commit.

---

## Pooling note (Supabase / PgBouncer)

- API requests: one RPC ≈ one transaction; `set_config(..., true)` flags are transaction-local.
- Tenant context for shop paths uses **per-request headers**, not session GUC on pooled connections ([architecture](../architecture/database.md)).
- Do not use connection-level `SET` for tenant or user context.

## Pooler discipline (Supabase)

- Money RPCs: **no session-level `SET`** and no `set_config(..., false)`.
- PostgREST / transaction pooler (port 6543): one RPC = one transaction — default for all `bills_pays` writers. `[verify against current Supabase docs]`
- Use session pooler (5432) or direct DB only for migrations, pgTAP, pg_cron, and drivers that require named prepared statements.
- See [PHASE-C-SUPABASE-RUNTIME.md](PHASE-C-SUPABASE-RUNTIME.md) (connection policy table).
