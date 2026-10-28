/** AP voucher paper in channel_meta — books (BDT) vs foreign face on bills.due_amount. */

export function apBillPaperForeignTotal(
  channelMeta: Record<string, unknown> | null | undefined,
): number | null {
  const raw = channelMeta?.ap_paper;
  if (!raw || typeof raw !== 'object') return null;
  const paper = raw as Record<string, unknown>;
  const direct = Number(paper.foreign_total);
  if (Number.isFinite(direct) && direct > 0) return direct;
  const groups = paper.currency_groups;
  if (Array.isArray(groups) && groups.length === 1) {
    const g = groups[0] as Record<string, unknown> | undefined;
    const ft = Number(g?.foreign_total);
    if (Number.isFinite(ft) && ft > 0) return ft;
  }
  return null;
}

export function apBillPaperCurrencyCode(
  channelMeta: Record<string, unknown> | null | undefined,
): string {
  const raw = channelMeta?.ap_paper;
  if (!raw || typeof raw !== 'object') return 'BDT';
  const paper = raw as Record<string, unknown>;
  const code = String(paper.currency_code ?? '').trim();
  if (code) return code.toUpperCase();
  const groups = paper.currency_groups;
  if (Array.isArray(groups) && groups.length === 1) {
    const g = groups[0] as Record<string, unknown> | undefined;
    const c = String(g?.currency_code ?? '').trim();
    if (c) return c.toUpperCase();
  }
  return 'BDT';
}

/** AP voucher: books due from kernel `open_books`; foreign face from `open_txn` or ap_paper. */
export function apBillDueStoresForeignFace(
  channelMeta: Record<string, unknown> | null | undefined,
  dueAmount: number,
): boolean {
  const foreign = apBillPaperForeignTotal(channelMeta);
  const code = apBillPaperCurrencyCode(channelMeta);
  if (!foreign || foreign <= 0 || code === 'BDT') return false;
  const due = Math.max(0, Number(dueAmount) || 0);
  return due > 0 && Math.abs(due - foreign) < 0.02;
}

/** Books-currency due for pay-in / pay-out (BDT). */
export function apBillBooksDueBdt(
  channelMeta: Record<string, unknown> | null | undefined,
  dueAmount: number,
  exchangeRate?: number | null,
): number {
  const due = Math.max(0, Number(dueAmount) || 0);
  if (!apBillDueStoresForeignFace(channelMeta, due)) return due;
  const rate = Number(exchangeRate) || 0;
  const foreign = apBillPaperForeignTotal(channelMeta) ?? due;
  if (rate > 0) return Math.round(foreign * rate * 100) / 100;
  const paper = channelMeta?.ap_paper as Record<string, unknown> | undefined;
  const paperRate = Number(paper?.conversion_rate);
  if (paperRate > 0 && Math.abs(paperRate - 1) > 0.0001) {
    return Math.round(foreign * paperRate * 100) / 100;
  }
  return 0;
}
