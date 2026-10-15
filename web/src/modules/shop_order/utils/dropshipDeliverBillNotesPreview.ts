import { Dialog } from 'quasar';
import DropshipMarkDeliveredConfirmDialog from '../components/DropshipMarkDeliveredConfirmDialog.vue';

export type DropshipBillNoteAdjustmentPreview = {
  bill_id: number;
  invoice_no: string | null;
  display_name?: string | null;
  invoice_type?: string | null;
  label: 'customer_invoice' | 'courier_ap';
  adjustment_kind: 'debit_note' | 'credit_note';
  amount: number;
  current_net: number;
  wanted_net: number;
  reason: string;
  detail_parts?: string[];
};

export type DropshipDeliverBillNotesPreview = {
  success: boolean;
  error?: string;
  has_adjustments?: boolean;
  skipped?: boolean;
  reason?: string;
  customer_invoice?: DropshipBillNoteAdjustmentPreview | null;
  courier_ap?: DropshipBillNoteAdjustmentPreview | null;
};

function toNumber(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const n = Number(value);
    if (Number.isFinite(n)) return n;
  }
  return 0;
}

function normalizeDetailParts(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((v) => String(v)).filter((s) => s.length > 0);
  }
  return [];
}

export function normalizeDropshipBillNoteAdjustment(
  raw: unknown,
  fallbackLabel: 'customer_invoice' | 'courier_ap',
): DropshipBillNoteAdjustmentPreview | null {
  if (!raw || typeof raw !== 'object') return null;
  const o = raw as Record<string, unknown>;
  const kind = o.adjustment_kind;
  if (kind !== 'debit_note' && kind !== 'credit_note') return null;

  const label = o.label === 'courier_ap' || o.label === 'customer_invoice'
    ? o.label
    : fallbackLabel;

  return {
    bill_id: toNumber(o.bill_id),
    invoice_no: typeof o.invoice_no === 'string' ? o.invoice_no : null,
    display_name: typeof o.display_name === 'string' ? o.display_name : null,
    invoice_type: typeof o.invoice_type === 'string' ? o.invoice_type : null,
    label,
    adjustment_kind: kind,
    amount: toNumber(o.amount),
    current_net: toNumber(o.current_net),
    wanted_net: toNumber(o.wanted_net),
    reason: typeof o.reason === 'string' ? o.reason : '',
    detail_parts: normalizeDetailParts(o.detail_parts),
  };
}

export function listDropshipDeliverBillNoteAdjustments(
  preview: DropshipDeliverBillNotesPreview | null,
): DropshipBillNoteAdjustmentPreview[] {
  if (!preview?.success || preview.skipped) return [];

  const items: DropshipBillNoteAdjustmentPreview[] = [];
  const customer = normalizeDropshipBillNoteAdjustment(preview.customer_invoice, 'customer_invoice');
  const courier = normalizeDropshipBillNoteAdjustment(preview.courier_ap, 'courier_ap');
  if (customer) items.push(customer);
  if (courier) items.push(courier);
  return items;
}

export function parseDropshipDeliverBillNotesPreview(data: unknown): DropshipDeliverBillNotesPreview | null {
  if (!data || typeof data !== 'object') return null;
  const row = data as Record<string, unknown>;
  const success = row.success === true;
  const parsed: DropshipDeliverBillNotesPreview = {
    success,
    error: typeof row.error === 'string' ? row.error : undefined,
    has_adjustments: row.has_adjustments === true,
    skipped: row.skipped === true,
    reason: typeof row.reason === 'string' ? row.reason : undefined,
    customer_invoice: normalizeDropshipBillNoteAdjustment(row.customer_invoice, 'customer_invoice'),
    courier_ap: normalizeDropshipBillNoteAdjustment(row.courier_ap, 'courier_ap'),
  };
  if (parsed.has_adjustments !== true && listDropshipDeliverBillNoteAdjustments(parsed).length > 0) {
    parsed.has_adjustments = true;
  }
  return parsed;
}

export function requestDropshipMarkDeliveredConfirmation(
  preview: DropshipDeliverBillNotesPreview | null,
  options?: { orderNo?: string | null },
): Promise<boolean> {
  return new Promise((resolve) => {
    Dialog.create({
      component: DropshipMarkDeliveredConfirmDialog,
      componentProps: {
        preview,
        orderNo: options?.orderNo ?? null,
      },
    })
      .onOk(() => resolve(true))
      .onCancel(() => resolve(false))
      .onDismiss(() => resolve(false));
  });
}
