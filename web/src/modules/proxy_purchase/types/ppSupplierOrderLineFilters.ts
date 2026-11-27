import type { PpOrderLinePlacementStatus } from './ppPurchaseRequest';

export type PpSupplierOrderLineListFilters = {
  placement_statuses: PpOrderLinePlacementStatus[];
};

export const emptyPpSupplierOrderLineListFilters = (): PpSupplierOrderLineListFilters => ({
  placement_statuses: [],
});

export const countActivePpSupplierOrderLineFilters = (
  filters: PpSupplierOrderLineListFilters,
): number => (filters.placement_statuses.length > 0 ? 1 : 0);

export const serializePpSupplierOrderLineListFilters = (
  filters: PpSupplierOrderLineListFilters,
): string =>
  JSON.stringify({
    p: [...filters.placement_statuses].sort(),
  });