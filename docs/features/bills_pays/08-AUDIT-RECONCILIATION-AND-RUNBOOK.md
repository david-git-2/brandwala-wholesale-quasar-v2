# Audit, reconciliation, and runbook

**Job:** Production maintenance — balance drift SQL, orphaned funds, drawer mismatch, and SOPs for cheque bounce, till transfer, count variance.

Run on read replica when possible. Live columns: `invoice_status`, `pay_allocations.bill_id` / `invoice_id` / `global_invoice_id`.

---

## 1. Net balance integrity

```sql
SELECT
  b.id,
  b.invoice_no,
  b.total_amount,
  COALESCE(SUM(pa.amount), 0) AS total_allocated,
  (b.total_amount - COALESCE(SUM(pa.amount), 0)) AS calculated_due,
  b.due_amount AS stored_due
FROM public.bills b
LEFT JOIN public.pay_allocations pa
  ON pa.bill_id = b.id OR pa.global_invoice_id = b.id OR pa.invoice_id = b.id
WHERE b.invoice_status = 'issued'
GROUP BY b.id
HAVING (b.total_amount - COALESCE(SUM(pa.amount), 0)) IS DISTINCT FROM b.due_amount;
```

Kernel truth: `SELECT public.get_bill_net_balances(:id);` (includes notes).

---

## 1b. Settlements vs pay allocations (BP18 cutover gate)

Run before switching readers to `bill_settlements`. Expect **zero rows** during dual-write; after cutover, retire this query or scope to legacy backfill only.

```sql
SELECT
  pa.id AS pay_allocation_id,
  pa.payment_id,
  public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id) AS bill_id,
  pa.amount AS alloc_books,
  bs.allocated_books_amount AS settlement_books,
  bs.id AS settlement_id
FROM public.pay_allocations pa
LEFT JOIN public.bill_settlements bs
  ON bs.pay_allocation_id = pa.id
  OR (
    bs.pay_allocation_id IS NULL
    AND bs.allocator_kind = 'pay'
    AND bs.allocator_id = pa.payment_id
    AND bs.bill_id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
    AND bs.allocated_books_amount = pa.amount
  )
WHERE pa.amount IS DISTINCT FROM bs.allocated_books_amount
   OR bs.id IS NULL;
```

Per payment (same pay id, all allocs on that pay):

```sql
SELECT pa.payment_id
FROM public.pay_allocations pa
GROUP BY pa.payment_id
HAVING coalesce(sum(pa.amount), 0) IS DISTINCT FROM coalesce((
  SELECT sum(bs.allocated_books_amount)
  FROM public.bill_settlements bs
  WHERE bs.allocator_kind = 'pay'
    AND bs.allocator_id = pa.payment_id
), 0);
```

Post-cutover: allocations-vs-settlements audit is optional; kernel readers use `bill_settlements` only.

---

## 2. Physical pot vs ledger

```sql
SELECT
  p.id AS pot_id,
  p.currency_code,
  p.amount AS physical_pot_balance,
  COALESCE(SUM(
    CASE WHEN ce.type = 'credit' THEN ce.amount ELSE -ce.amount END
  ), 0) AS ledger_net
FROM public.cashbook_point_pots p
LEFT JOIN public.cashbook_entries ce ON ce.cashbook_point_pot_id = p.id
GROUP BY p.id, p.currency_code, p.amount
HAVING p.amount IS DISTINCT FROM COALESCE(SUM(
  CASE WHEN ce.type = 'credit' THEN ce.amount ELSE -ce.amount END
), 0);
```

---

## 3. Orphaned unallocated pay

```sql
SELECT
  p.id,
  p.profile_id,
  p.unallocated_amount,
  p.amount
FROM public.pays p
WHERE COALESCE(p.unallocated_amount, 0) > 0
  AND NOT EXISTS (
    SELECT 1
    FROM public.cashbook_entries ce
    WHERE ce.source_id = p.id::text
      AND ce.source_type IN ('payment_leftover', 'customer_receipt', 'payment')
  );
```

---

## 4. Issued bill mutation smell

```sql
SELECT id, invoice_no, updated_at, total_amount, invoice_status
FROM public.bills
WHERE invoice_status = 'issued'
  AND updated_at > created_at + interval '1 minute'
ORDER BY updated_at DESC
LIMIT 50;
```

---

## SOP: Cheque bounce

1. Locate `pays` + `pay_allocations`.
2. **Target:** `kernel_reverse_payment` — void allocs, reverse custody, reopen due ([WA13](../features/bills_pays/00-gaps.md)).
3. Do not `UPDATE bills.total_amount`.
4. Re-collect when cheque clears.

---

## SOP: Point-to-point cash transfer

Single transaction: debit pot A, credit pot B; `source_type = point_transfer` ([BP15](../features/bills_pays/00-gaps.md)).

---

## SOP: Till count variance

1. Physical count vs `cashbook_point_pots.amount`.
2. Adjustment via `record_ledger_transaction` (`source_type = till_adjustment`).
3. Reason in metadata; manager approval out of band.

---

## Escalation

| Symptom | Check |
| :--- | :--- |
| AR paid but report shows due | `get_bill_net_balances`, note children |
| Landed cost wrong | Paid AP `exchange_rate`, `refresh_global_shipment_fx_from_ap_payments` |
| Dropship payout stuck | Merchant custody vs `dispense_middleman_payout_from_tenant` |
| Double bill on order | Source plug uniqueness when BP9 live |

[REFERENCE.md](REFERENCE.md) · [tests.md](../features/bills_pays/tests.md) · [bills_pays/spec](../features/bills_pays/spec.md)

---

## PITR recovery (production)

1. Stop money writers (disable routes or revoke execute on writers — break-glass).
2. Choose restore time **T0** before the incident (audit log / last good pay id).
3. Restore via Supabase **PITR** to T0 (new branch or project). `[verify against current Supabase docs]`
4. Run §1–§3 audit SQL; reconcile **physical cash** vs `cashbook_point_pots` and **frozen** `cashbook_entries.exchange_rate` (invariant #5).
5. Replay forward migrations only after root-cause fix. Never `UPDATE` issued `total_amount` in the SQL editor.

**Tier:** **Pro or above** for production money ledger (PITR + connection headroom). Free tier is not sufficient.

## Scheduled audits (pg_cron)

Optional daily job for §3 orphan-unallocated pattern — alert only, no auto-mutation (pg_cron when enabled).
