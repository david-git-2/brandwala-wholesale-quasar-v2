export type DropshipPlaceOrderStepId =
  | 'lock_qty'
  | 'resell_price'
  | 'delivery'
  | 'cost_distribution'
  | 'confirmation'
  | 'place_order';

export interface DropshipPlaceOrderStepDef {
  id: DropshipPlaceOrderStepId;
  labelKey: string;
  shortLabelKey: string;
}

export const DROPSHIP_PLACE_ORDER_STEPS: DropshipPlaceOrderStepDef[] = [
  {
    id: 'lock_qty',
    labelKey: 'shop.dropship_step_lock_qty',
    shortLabelKey: 'shop.dropship_step_lock_qty_short',
  },
  {
    id: 'resell_price',
    labelKey: 'shop.dropship_step_resell',
    shortLabelKey: 'shop.dropship_step_resell_short',
  },
  {
    id: 'delivery',
    labelKey: 'shop.dropship_step_delivery',
    shortLabelKey: 'shop.dropship_step_delivery_short',
  },
  {
    id: 'cost_distribution',
    labelKey: 'shop.dropship_step_cost',
    shortLabelKey: 'shop.dropship_step_cost_short',
  },
  {
    id: 'confirmation',
    labelKey: 'shop.dropship_step_confirmation',
    shortLabelKey: 'shop.dropship_step_confirmation_short',
  },
  {
    id: 'place_order',
    labelKey: 'shop.dropship_step_place',
    shortLabelKey: 'shop.dropship_step_place_short',
  },
];

export const DROPSHIP_PLACE_ORDER_STEP_COUNT = DROPSHIP_PLACE_ORDER_STEPS.length;