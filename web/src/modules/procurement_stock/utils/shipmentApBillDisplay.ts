import type { RouteLocationRaw } from 'vue-router';
import { shipmentApKindLabel } from '../constants/shipmentApBuckets';
import type { ShipmentApBillRow } from '../repositories/shipmentApBillsRepository';
import { shipmentApBillBucket } from '../repositories/shipmentApBillsRepository';

export type ApBillStatusChip = { label: string; color: string; textColor: string };

export function displayBillTotal(bill: ShipmentApBillRow): number {
  const nb = bill.net_balances;
  const booksTotal = Number(bill.total_amount) || 0;
  if (booksTotal > 0) return booksTotal;
  if (nb?.original_total != null && nb.original_total > 0) return nb.original_total;
  const openTxn = nb?.open_txn ?? 0;
  const paid = nb?.paid_amount ?? 0;
  if (openTxn > 0 || paid > 0) return openTxn + paid;
  return booksTotal;
}

export function displayDueAmount(bill: ShipmentApBillRow): number {
  const nb = bill.net_balances;
  const openBooks = nb?.open_books;
  if (openBooks != null && openBooks > 0) return openBooks;
  const openTxn = nb?.open_txn;
  if (openTxn != null && openTxn > 0) return openTxn;
  const kernelDue = nb?.due_amount;
  if (kernelDue != null && Number.isFinite(kernelDue) && kernelDue > 0) return kernelDue;
  return Number(bill.due_amount) || 0;
}

export function apBillStatusChip(bill: ShipmentApBillRow): ApBillStatusChip | null {
  if (bill.invoice_status === 'draft') {
    return { label: 'Draft', color: 'grey-2', textColor: 'grey-8' };
  }
  if (bill.payment_status === 'paid' || displayDueAmount(bill) <= 0) {
    return { label: 'Paid', color: 'green-1', textColor: 'green-9' };
  }
  if (displayDueAmount(bill) > 0) {
    return { label: 'Due', color: 'orange-1', textColor: 'orange-9' };
  }
  return null;
}

export function apBillInvoiceLabel(bill: ShipmentApBillRow): string {
  if (bill.invoice_status === 'issued' && bill.invoice_no) {
    return bill.invoice_no;
  }
  if (bill.invoice_status === 'draft') {
    return 'Draft — open bill to issue';
  }
  return bill.invoice_status ?? '—';
}

export function apBillKindLabel(bill: ShipmentApBillRow): string {
  const bucket = shipmentApBillBucket(bill);
  const base = bucket ? shipmentApKindLabel(bucket) : 'AP';
  const key = bill.source_key ?? bill.ap_kind;
  if (key && bill.ap_kind && key !== bill.ap_kind) {
    return `${base} (${key})`;
  }
  return base;
}

export function billDetailRoute(billId: number, tenantSlug: string | null | undefined): RouteLocationRaw | null {
  if (!tenantSlug) return null;
  return {
    name: 'app-bill-detail-page',
    params: { tenantSlug, billId: String(billId) },
  };
}

export function sumApBillsDue(bills: ShipmentApBillRow[]): number {
  return bills.reduce((s, b) => s + displayDueAmount(b), 0);
}

export function sumApBillsTotal(bills: ShipmentApBillRow[]): number {
  return bills.reduce((s, b) => s + displayBillTotal(b), 0);
}
