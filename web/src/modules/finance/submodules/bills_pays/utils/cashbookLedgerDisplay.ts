import type { CashbookLedgerRow } from '../repositories/cashbookRepository';

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

function metaString(meta: Record<string, unknown> | null | undefined, key: string): string | null {
  const v = meta?.[key];
  if (v == null) return null;
  const s = String(v).trim();
  return s || null;
}

/** Pay id when this ledger line came from a kernel pay writer. */
export function cashbookLedgerPayId(
  line: Pick<CashbookLedgerRow, 'source_id' | 'metadata'>,
): number | null {
  const fromMeta = metaString(line.metadata, 'payment_id');
  const raw = fromMeta ?? line.source_id;
  if (!raw?.trim()) return null;
  const id = Number(raw);
  return Number.isFinite(id) && id > 0 ? Math.trunc(id) : null;
}

/** Primary human label for the Source column. */
export function formatCashbookLedgerSourceTitle(
  line: Pick<CashbookLedgerRow, 'source_type' | 'metadata'>,
): string {
  const label = metaString(line.metadata, 'label');
  if (label) return label;

  const purpose = metaString(line.metadata, 'purpose');
  if (purpose === 'ap_payout') return 'AP pay out';
  if (purpose === 'commission') return 'Commission pay out';

  const txnType = metaString(line.metadata, 'transaction_type');
  if (txnType === 'ap_paid_out') return 'AP pay out';
  if (txnType === 'manual_adjustment') {
    const action = metaString(line.metadata, 'action_type');
    if (action === 'pay') return 'Manual pay out';
    if (action === 'deposit') return 'Manual deposit';
    if (action === 'withdraw') return 'Manual withdraw';
    if (action === 'credit') return 'Manual credit';
  }

  const sourceType = (line.source_type ?? '').trim().toLowerCase();
  switch (sourceType) {
    case 'payout':
      return 'Pay out';
    case 'sales_invoice':
      return 'Customer payment';
    case 'sales_invoice_return':
      return 'Refund';
    case 'shop_order':
      return 'Shop order';
    case 'point_transfer':
      return 'Move cash';
    case 'bill_settlement':
      return 'Bill settlement';
    case 'deposit':
      return 'Deposit';
    case 'adjustment':
      return 'Adjustment';
    default:
      return line.source_type?.trim() || '—';
  }
}

/** Secondary line: till, method, reference (excludes pay id — use link separately). */
export function cashbookLedgerSourceDetailParts(
  line: Pick<CashbookLedgerRow, 'cashbook_point_name' | 'metadata'>,
): string[] {
  const parts: string[] = [];
  if (line.cashbook_point_name?.trim()) {
    parts.push(line.cashbook_point_name.trim());
  }
  const method = metaString(line.metadata, 'method');
  if (method) parts.push(method);
  const reference = metaString(line.metadata, 'reference');
  if (reference) parts.push(reference);
  const note = metaString(line.metadata, 'note');
  if (note && !reference) parts.push(note);
  return parts;
}

export function formatCashbookLedgerSourceDetail(
  line: Pick<CashbookLedgerRow, 'cashbook_point_name' | 'metadata'>,
): string {
  const parts = cashbookLedgerSourceDetailParts(line);
  return parts.length ? parts.join(' · ') : '';
}
