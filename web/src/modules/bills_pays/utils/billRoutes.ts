import type { RouteLocationRaw } from 'vue-router';
import { buildModuleRoutePath } from 'src/modules/navigation/moduleRegistry';

export const BILLS_ROUTE_SEGMENT = 'bills';

export function billListPath(tenantSlug: string | null | undefined): string {
  return buildModuleRoutePath({ scope: 'app', routeSegment: BILLS_ROUTE_SEGMENT, tenantSlug });
}

export function billListRoute(tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bills-page',
    params: tenantSlug ? { tenantSlug } : {},
  };
}

export function billComposeRoute(tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-compose-page',
    params: tenantSlug ? { tenantSlug } : {},
  };
}

/** Open an existing draft / proforma on the AR compose desk (Issue, Save, Note). */
export function billDraftComposeRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-compose-page',
    params: tenantSlug ? { tenantSlug } : {},
    query: { id: String(billId) },
  };
}

export function billDetailRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-detail-page',
    params: { ...(tenantSlug ? { tenantSlug } : {}), billId: String(billId) },
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

export type BillDetailAdjustmentQuery = {
  startAdjustment?: '1';
  reason?: string;
  suggestedAmount?: string;
};

export function billDetailCommercialCreditRoute(
  billId: number,
  tenantSlug?: string | null,
  query?: BillDetailAdjustmentQuery,
): RouteLocationRaw {
  return {
    name: 'app-bill-detail-page',
    params: { ...(tenantSlug ? { tenantSlug } : {}), billId: String(billId) },
    query: query ?? {},
  };
}

export function billPreviewRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-preview-page',
    params: { ...(tenantSlug ? { tenantSlug } : {}), billId: String(billId) },
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
}): boolean {
  const st = bill.invoice_status;
  if (st !== 'draft' && st !== 'proforma_generated') return false;
  if (bill.invoice_type === 'ap') return true;
  if (bill.source_type === 'shipment_cost') return true;
  if (bill.ap_shipment_id != null) return true;
  return isDeliveryPaperOutcomeBillSource(bill.source_type, bill.source_key);
}
