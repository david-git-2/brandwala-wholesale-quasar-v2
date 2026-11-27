import { PP_SUPPLIER_LIST_EXCLUDE_PLACEMENT_STATUSES } from '../../utils/ppOrderLinePlacement';

export const ppSupplierListExcludePlacementsCacheKey = () =>
  [...PP_SUPPLIER_LIST_EXCLUDE_PLACEMENT_STATUSES].sort().join(',');

export const ppPurchaseQueryKeys = {
  customerRequests: (tenantId: number | null | undefined) =>
    ['pp-purchase-customer-requests', tenantId] as const,
  request: (tenantId: number | null | undefined, requestId: number | null | undefined) =>
    ['pp-purchase-request', tenantId, requestId] as const,
  requestLines: (tenantId: number | null | undefined, requestId: number | null | undefined) =>
    ['pp-purchase-request-lines', tenantId, requestId] as const,
  customerOrderLines: (tenantId: number | null | undefined) =>
    ['pp-purchase-customer-order-lines', tenantId] as const,
  supplierOrderLines: (
    tenantId: number | null | undefined,
    peopleGroupMemberId: number | null | undefined,
    excludePlacementsKey: string | null | undefined,
    filtersKey: string | null | undefined,
  ) =>
    [
      'pp-purchase-supplier-order-lines',
      tenantId,
      peopleGroupMemberId,
      excludePlacementsKey ?? '',
      filtersKey ?? '',
    ] as const,
  staffRequests: (tenantId: number | null | undefined) =>
    ['pp-purchase-staff-requests', tenantId] as const,
  staffOrderLines: (
    tenantId: number | null | undefined,
    filtersKey: string | null | undefined,
  ) => ['pp-purchase-staff-order-lines', tenantId, filtersKey ?? ''] as const,
  staffOrderLineFilterOptions: (tenantId: number | null | undefined) =>
    ['pp-purchase-staff-order-line-filter-options', tenantId] as const,
};