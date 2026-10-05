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
