import type { RouteLocationRaw } from 'vue-router';
import { buildModuleRoutePath } from 'src/modules/navigation/moduleRegistry';
import type { GlobalInvoiceDetail } from 'src/modules/bills_pays/types/invoice';
import { isDropshipManagerBill } from './dropshipManagedBill';

export const BILLS_ROUTE_SEGMENT = 'bills';

export function billListPath(tenantSlug: string | null | undefined): string {
  return buildModuleRoutePath({ scope: 'app', routeSegment: BILLS_ROUTE_SEGMENT, tenantSlug });
}

export function billListRoute(_tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bills-page',
  };
}

export function billComposeRoute(tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-compose-page',
  };
}

/** Open an existing draft / proforma on the AR compose desk (Issue, Save, Note). */
export function billDraftComposeRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-compose-page',
    query: { id: String(billId) },
  };
}

export function billDetailRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-detail-page',
    params: { billId: String(billId) },
  };
}

export function billPayRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-pay-page',
    params: { billId: String(billId) },
  };
}

export type BillVendorRefundQuery = {
  creditNoteId?: string;
};

export function billVendorRefundRoute(
  billId: number,
  tenantSlug?: string | null,
  query?: BillVendorRefundQuery,
): RouteLocationRaw {
  return {
    name: 'app-bill-vendor-refund-page',
    params: { billId: String(billId) },
    query: query?.creditNoteId ? { creditNoteId: query.creditNoteId } : undefined,
  };
}

/** Credit / debit note composer (opens in a new tab from bill detail). */
export function billAdjustmentRoute(
  billId: number,
  tenantSlug?: string | null,
  query?: BillDetailAdjustmentQuery,
): RouteLocationRaw {
  return {
    name: 'app-bill-adjustment-page',
    params: { billId: String(billId) },
    query: query
      ? {
          ...(query.startAdjustment ? { startAdjustment: query.startAdjustment } : {}),
          ...(query.reason ? { reason: query.reason } : {}),
          ...(query.suggestedAmount ? { suggestedAmount: query.suggestedAmount } : {}),
          ...(query.adjustmentKind ? { adjustmentKind: query.adjustmentKind } : {}),
        }
      : undefined,
  };
}

/** Compose desk for drafts; detail for issued bills (matches bills list). */
export function billRouteForInvoiceStatus(
  billId: number,
  invoiceStatus: string | null | undefined,
  tenantSlug?: string | null,
): RouteLocationRaw {
  if (invoiceStatus === 'draft' || invoiceStatus === 'proforma_generated') {
    return billDraftComposeRoute(billId, tenantSlug);
  }
  return billDetailRoute(billId, tenantSlug);
}

export type BillDetailAdjustmentKind = 'credit_note' | 'debit_note' | 'write_off';

export type BillDetailAdjustmentQuery = {
  startAdjustment?: '1';
  reason?: string;
  suggestedAmount?: string;
  /** Pre-select composer mode (AP detail opens credit note or write-off in separate tabs). */
  adjustmentKind?: BillDetailAdjustmentKind;
};

export function billDetailCommercialCreditRoute(
  billId: number,
  tenantSlug?: string | null,
  query?: BillDetailAdjustmentQuery,
): RouteLocationRaw {
  return billAdjustmentRoute(billId, tenantSlug, query);
}

export function billPreviewRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-preview-page',
    params: { billId: String(billId) },
  };
}

/** Draft bills from delivery paper Accept/Condition — detail + Issue, not compose desk. */
export function isDeliveryPaperOutcomeBillSource(
  sourceType: string | null | undefined,
  sourceKey: string | null | undefined,
): boolean {
  if (sourceType === 'delivery_close') return true;
  return sourceType === 'shop_order' && String(sourceKey ?? '').startsWith('delivery_paper:');
}

export function billOpensOnDetailNotComposeDesk(bill: {
  invoice_status?: string | null;
  invoice_type?: string | null;
  source_type?: string | null;
  source_key?: string | null;
  ap_shipment_id?: number | null;
  shop_order_id?: number | null;
  invoice_no?: string | null;
  ap_kind?: string | null;
}): boolean {
  const st = bill.invoice_status;
  if (st !== 'draft' && st !== 'proforma_generated') return false;
  if (bill.source_type === 'dropship_courier_ar') return true;
  if (isDropshipManagerBill(bill as GlobalInvoiceDetail)) return true;
  if (bill.invoice_type === 'ap') return true;
  if (bill.source_type === 'shipment_cost') return true;
  if (bill.ap_shipment_id != null) return true;
  return isDeliveryPaperOutcomeBillSource(bill.source_type, bill.source_key);
}

function positiveInt(value: string | number | null | undefined): number | null {
  if (value == null) return null;
  const id = typeof value === 'number' ? value : Number(String(value).trim());
  return Number.isFinite(id) && id > 0 ? id : null;
}

/** Delivery paper id from `delivery_close` source_id or `delivery_paper:{id}:…` source_key. */
export function deliveryPaperIdFromBillSource(
  sourceType: string | null | undefined,
  sourceId: string | null | undefined,
  sourceKey: string | null | undefined,
): number | null {
  if (sourceType === 'delivery_close') {
    return positiveInt(sourceId);
  }
  const key = sourceKey?.trim() ?? '';
  if (!key.startsWith('delivery_paper:')) return null;
  const parts = key.split(':');
  return positiveInt(parts[1]);
}

export type BillKernelSourceRouteInput = {
  sourceType?: string | null;
  sourceId?: string | null;
  sourceKey?: string | null;
  shipmentId?: number | null;
  shopOrderId?: number | null;
};

/** Staff app route for the bill’s kernel source, or null when there is no navigable source. */
export function billKernelSourceRoute(
  input: BillKernelSourceRouteInput,
  tenantSlug?: string | null,
): RouteLocationRaw | null {
  const slugParams = tenantSlug ? { tenantSlug } : {};

  const paperId = deliveryPaperIdFromBillSource(input.sourceType, input.sourceId, input.sourceKey);
  if (paperId != null) {
    const orderFromProp = positiveInt(input.shopOrderId);
    const orderFromSource =
      input.sourceType === 'shop_order' ? positiveInt(input.sourceId) : null;
    const orderId = orderFromProp ?? orderFromSource;
    if (orderId != null) {
      return {
        name: 'app-shop-order-delivery-paper-page',
        params: { ...slugParams, id: String(orderId), paperId: String(paperId) },
      };
    }
    return {
      name: 'app-procurement-fulfill-delivery-paper-page',
      params: { ...slugParams, paperId: String(paperId) },
    };
  }

  if (input.sourceType === 'shipment_cost') {
    const sid = positiveInt(input.shipmentId) ?? positiveInt(input.sourceId);
    if (sid != null) {
      return {
        name: 'app-procurement-shipment-details',
        params: { ...slugParams, id: String(sid) },
      };
    }
  }

  if (input.sourceType === 'shop_order') {
    const oid = positiveInt(input.shopOrderId) ?? positiveInt(input.sourceId);
    if (oid != null) {
      return {
        name: 'app-shop-order-detail-page',
        params: { ...slugParams, id: String(oid) },
      };
    }
  }

  return null;
}
