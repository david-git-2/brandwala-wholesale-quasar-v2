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

export function billDetailRoute(billId: number, tenantSlug?: string | null): RouteLocationRaw {
  return {
    name: 'app-bill-detail-page',
    params: { ...(tenantSlug ? { tenantSlug } : {}), billId: String(billId) },
  };
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
