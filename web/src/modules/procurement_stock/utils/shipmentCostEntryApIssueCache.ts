import type { ShipmentApBillRow } from '../repositories/shipmentApBillsRepository';
import type { GlobalShipmentCostEntry } from '../types/shipmentCostEntry';
import type { IssueShipmentCostEntryApV2Result } from '../repositories/globalShipmentCostEntryRepository';
import type { ShipmentApKind } from '../constants/shipmentApBuckets';

export const shipmentApBillRowFromCostEntryIssue = (
  result: IssueShipmentCostEntryApV2Result,
  entry: Pick<GlobalShipmentCostEntry, 'id' | 'shipment_id' | 'cost_bucket' | 'amount'>,
): ShipmentApBillRow => {
  const total = Number(result.total_amount);
  const due = Number(result.due_amount);
  const entryAmount = Number(entry.amount) || 0;
  const apKind = (result.ap_kind ?? entry.cost_bucket) as ShipmentApKind;
  return {
    id: Number(result.bill_id),
    invoice_no: String(result.invoice_no ?? ''),
    ap_kind: apKind,
    source_type: result.source_type ?? 'shipment_cost',
    source_id: result.source_id ?? String(entry.shipment_id),
    source_key: result.source_key ?? `entry:${entry.id}`,
    invoice_status: String(result.status ?? 'issued'),
    payment_status: null,
    total_amount: Number.isFinite(total) ? total : entryAmount,
    due_amount: Number.isFinite(due) ? due : entryAmount,
  };
};

export const mergeShipmentApBillIntoList = (
  bills: ShipmentApBillRow[],
  row: ShipmentApBillRow,
): ShipmentApBillRow[] => {
  const next = bills.filter(
    (b) => b.id !== row.id && (b.source_key ?? '') !== (row.source_key ?? ''),
  );
  next.push(row);
  return next;
};
