import type { GlobalInvoiceRow } from './invoice';

export type BillAdjustmentRow = GlobalInvoiceRow & {
  document_kind?: string | null;
  parent_bill_id?: number | null;
  note?: string | null;
  channel_meta?: Record<string, unknown> | null;
};
