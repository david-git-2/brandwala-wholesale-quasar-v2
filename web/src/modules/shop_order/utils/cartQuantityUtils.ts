import type { ShopType } from '../types';

/** Catalog shop default step / minimum when product MOQ is ≤ this value. */
export const VENDOR_CATALOG_DEFAULT_MOQ = 6;

type MoqSource = {
  minimum_order_quantity?: number | null;
  minimum_quantity?: number | null;
  moq?: number | null;
};

/** fixed_price / dropship step by 1. vendor_catalog: min 6, or product MOQ when > 6. */
export function resolveShopCartItemMoq(
  item: MoqSource,
  shopType?: ShopType | null,
): number {
  if (shopType !== 'vendor_catalog') return 1;

  const productMoq = Math.floor(Number(item.minimum_order_quantity ?? item.moq ?? 0)) || 0;
  if (productMoq > VENDOR_CATALOG_DEFAULT_MOQ) return productMoq;
  return VENDOR_CATALOG_DEFAULT_MOQ;
}

export function adjustQtyByMoq(currentQty: number, delta: number, moq: number): number {
  const step = Math.max(1, Number(moq) || 1);
  const current = Math.max(step, Number(currentQty) || step);
  const stepDelta = Number(delta) || (delta < 0 ? -step : step);
  let next = current + stepDelta;
  if (next < step) next = step;
  return next;
}
