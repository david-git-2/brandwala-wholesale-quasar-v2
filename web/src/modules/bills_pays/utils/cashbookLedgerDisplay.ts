/** Ledger row date as yyyy-mm-dd (local calendar day). */
export function formatCashbookLedgerDate(iso: string | null | undefined): string {
  if (!iso?.trim()) return '—';
  const s = iso.trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return s;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Plain labels for cashbook_entries.type (credit / debit). */
export function formatCashbookLedgerType(type: string | null | undefined): string {
  const t = (type ?? '').trim().toLowerCase();
  if (t === 'credit') return 'Money in';
  if (t === 'debit') return 'Money out';
  if (!t) return '—';
  return type!.trim();
}

export function isCashbookLedgerDeduction(type: string | null | undefined): boolean {
  return (type ?? '').trim().toLowerCase() === 'debit';
}
