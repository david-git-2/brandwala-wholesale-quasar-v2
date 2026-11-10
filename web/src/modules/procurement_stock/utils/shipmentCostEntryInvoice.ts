import type { Json } from 'src/types/database.types';

export function costEntryApBillId(metadata: Json | Record<string, unknown> | null | undefined): number | null {
  const meta = (metadata ?? {}) as Record<string, unknown>;
  const id = Number(meta.ap_bill_id);
  return Number.isFinite(id) && id > 0 ? id : null;
}

export function costEntryHasIssuedInvoice(metadata: Json | Record<string, unknown> | null | undefined): boolean {
  return costEntryApBillId(metadata) != null;
}
