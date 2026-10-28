export type FifoBillRow = {
  id: number;
  due_amount: number;
  invoice_date?: string | null;
};

export function fifoFillByOldest(bills: FifoBillRow[], cash: number): Map<number, number> {
  const remainingStart = Math.max(0, Number(cash) || 0);
  let remaining = remainingStart;
  const ordered = [...bills].sort((a, b) => {
    const da = a.invoice_date ?? '';
    const db = b.invoice_date ?? '';
    if (da !== db) return da.localeCompare(db);
    return a.id - b.id;
  });
  const filled = new Map<number, number>();
  for (const bill of ordered) {
    if (remaining <= 0) break;
    const due = Math.max(0, Number(bill.due_amount) || 0);
    const take = Math.min(due, remaining);
    if (take > 0) {
      filled.set(bill.id, take);
      remaining -= take;
    }
  }
  return filled;
}

export type PreApplyPool = {
  kind: 'credit_note' | 'pay';
  allocator_id: number;
  pool: number;
};

export type PreApplySettlementLine = {
  bill_id: number;
  amount: number;
  allocator_kind: 'credit_note' | 'pay';
  allocator_id: number;
};

/** FIFO each pool onto bills; reduces working due after each pool. */
export function buildPreApplySettlementLines(
  bills: FifoBillRow[],
  pools: PreApplyPool[],
): PreApplySettlementLine[] {
  const working = bills.map((b) => ({
    id: b.id,
    due_amount: Math.max(0, Number(b.due_amount) || 0),
    invoice_date: b.invoice_date,
  }));
  const lines: PreApplySettlementLine[] = [];
  for (const pool of pools) {
    if (pool.pool <= 0) continue;
    const filled = fifoFillByOldest(working, pool.pool);
    for (const [billId, amt] of filled) {
      lines.push({
        bill_id: billId,
        amount: amt,
        allocator_kind: pool.kind,
        allocator_id: pool.allocator_id,
      });
      const row = working.find((w) => w.id === billId);
      if (row) row.due_amount = Math.max(0, row.due_amount - amt);
    }
  }
  return lines;
}
