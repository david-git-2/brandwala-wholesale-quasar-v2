import {
  getItemRemainingToDeliver,
  type ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';

export type DeliveryPaperRemainingContext = Pick<
  ProcurementDemandItem,
  'remaining_to_deliver' | 'quantity' | 'delivered_quantity'
> & {
  remaining_to_pack?: number;
  packed_on_other_delivery_papers?: number;
};

/** Max packed qty allowed on this delivery paper line (excludes picks already saved on other papers). */
export const getDeliveryPaperLinePickCap = (item: DeliveryPaperRemainingContext): number => {
  if (item.remaining_to_pack != null && Number.isFinite(item.remaining_to_pack)) {
    return Math.max(0, Math.trunc(item.remaining_to_pack));
  }
  const orderRemaining = getItemRemainingToDeliver(item);
  const onOther = Math.max(0, Math.trunc(item.packed_on_other_delivery_papers ?? 0));
  return Math.max(0, orderRemaining - onOther);
};

/** Remaining column: order left to deliver minus packed on this paper and other papers. */
export const getDeliveryPaperLineRemainingToPack = (
  item: DeliveryPaperRemainingContext,
  packedOnThisPaper: number,
): number => {
  const cap = getDeliveryPaperLinePickCap(item);
  const onPaper = Math.max(0, Math.trunc(packedOnThisPaper));
  return Math.max(0, cap - onPaper);
};
