type MoqSource = {
  minimum_order_quantity?: number | null;
  minimum_quantity?: number | null;
  moq?: number | null;
};

/** Product MOQ wins over cart-item minimum_quantity (often 1 in DB). Dropship always steps by 1. */
export function resolveShopCartItemMoq(
  item: MoqSource,
  options?: { dropship?: boolean },
): number {
  if (options?.dropship) return 1;

  const productMoq = Number(item.minimum_order_quantity ?? item.moq ?? 0);
  if (productMoq > 1) return productMoq;

  const storedMin = Number(item.minimum_quantity ?? 0);
  return storedMin > 0 ? storedMin : 1;
}

export function adjustQtyByMoq(currentQty: number, delta: number, moq: number): number {
  const step = Math.max(1, Number(moq) || 1);
  const current = Math.max(step, Number(currentQty) || step);
  const stepDelta = Number(delta) || (delta < 0 ? -step : step);
  let next = current + stepDelta;
  if (next < step) next = step;
  return next;
}
