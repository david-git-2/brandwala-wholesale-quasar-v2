import type { PpOrderLine, PpSupplierOrderLineUpdatePayload } from '../types/ppPurchaseRequest';

export function buildPpSupplierOrderLineUpdate(
  line: PpOrderLine,
  patch: Partial<Omit<PpSupplierOrderLineUpdatePayload, 'lineId'>> = {},
): PpSupplierOrderLineUpdatePayload {
  return {
    lineId: line.id,
    placed_qty: patch.placed_qty !== undefined ? patch.placed_qty : line.placed_qty,
    placement_status: patch.placement_status ?? line.placement_status,
  };
}