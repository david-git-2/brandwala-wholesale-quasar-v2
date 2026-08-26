import type { DropshipInvoiceDeliveredQuantitiesState } from './dropshipInvoiceFulfillment';
import type { DropshipInvoiceSummaryState } from './dropshipInvoiceSummary';

export type DropshipV2CustomerInvoiceSnapshot = {
  summary: DropshipInvoiceSummaryState;
  deliveredQuantities: DropshipInvoiceDeliveredQuantitiesState;
};

export const buildDropshipV2CustomerInvoiceStorageKey = (orderId: number | string) =>
  `dropship-v2-customer-invoice:${orderId}`;

export function saveDropshipV2CustomerInvoiceSnapshot(
  orderId: number | string,
  snapshot: DropshipV2CustomerInvoiceSnapshot,
) {
  sessionStorage.setItem(
    buildDropshipV2CustomerInvoiceStorageKey(orderId),
    JSON.stringify(snapshot),
  );
}

export function loadDropshipV2CustomerInvoiceSnapshot(
  orderId: number | string,
): DropshipV2CustomerInvoiceSnapshot | null {
  const raw = sessionStorage.getItem(buildDropshipV2CustomerInvoiceStorageKey(orderId));
  if (!raw) return null;
  try {
    return JSON.parse(raw) as DropshipV2CustomerInvoiceSnapshot;
  } catch {
    return null;
  }
}
