import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';

/** Add or bump newest lot on this line without dropping other lots; total packed cannot exceed pick cap. */
export const mergeLastLotIntoPicks = (
  existing: DemandStockPickSelection[],
  pick: DemandStockPickSelection,
  pickCap: number,
): DemandStockPickSelection[] => {
  const cap = Math.max(0, Math.trunc(pickCap));
  const otherQty = existing
    .filter((p) => p.globalStockId !== pick.globalStockId)
    .reduce((sum, p) => sum + p.quantity, 0);
  const room = Math.max(0, cap - otherQty);
  const qty = Math.min(pick.quantity, room);
  if (qty <= 0) return existing;
  const rest = existing.filter((p) => p.globalStockId !== pick.globalStockId);
  return [...rest, { ...pick, quantity: qty }];
};