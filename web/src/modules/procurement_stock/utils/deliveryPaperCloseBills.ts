import type { DeliveryPaperCloseBill } from '../repositories/procurementDemandRepository';

export function deliveryPaperCloseBillChipLabel(bill: DeliveryPaperCloseBill): string {
  const no = bill.invoice_no?.trim() || `Bill #${bill.id}`;
  const kind = bill.settlement_kind?.toLowerCase();
  const prefix =
    kind === 'condition' ? 'Condition' : kind === 'take' ? 'Accept' : null;
  return prefix ? `${prefix} · ${no}` : no;
}

export function deliveryPaperCloseBillChipCaption(bill: DeliveryPaperCloseBill): string | undefined {
  if (bill.invoice_status === 'draft' || bill.invoice_status === 'proforma_generated') {
    return 'Open bill — issue to collect payment';
  }
  if (bill.invoice_status === 'issued') return 'Issued bill';
  return bill.invoice_status ?? undefined;
}
