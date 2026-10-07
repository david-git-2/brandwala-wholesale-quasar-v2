/** Mirrors `public.shop_padded_display_quantity`. */
export function shopPaddedDisplayQuantity(real: number, add = 6): number {
  const qty = Math.floor(Number(real) || 0);
  const pad = Math.max(Number(add) || 6, 0);
  if (qty <= 0) return 0;
  if (qty <= 2) return qty;
  return qty + pad;
}

/** Stale override left from sold-down stock; customer catalog ignores this. */
export function isStaleZeroShopDisplayOverride(
  override: number | null | undefined,
  real: number,
): boolean {
  return override === 0 && Math.floor(Number(real) || 0) > 0;
}

export function resolveShopDisplayQuantity(
  real: number,
  override: number | null | undefined,
  opts: {
    displayAdd?: number;
    quantityDisplayMode?: 'original' | 'custom_override';
  } = {},
): number {
  const actual = Math.floor(Number(real) || 0);
  const mode = opts.quantityDisplayMode ?? 'custom_override';
  const add = opts.displayAdd ?? 6;

  if (mode === 'original') {
    return Math.max(0, actual);
  }

  if (
    override !== null &&
    override !== undefined &&
    !isStaleZeroShopDisplayOverride(override, actual)
  ) {
    return override;
  }

  return shopPaddedDisplayQuantity(actual, add);
}

export function hasShopDisplayQuantityOverride(
  override: number | null | undefined,
  real: number,
): boolean {
  if (override === null || override === undefined) return false;
  return !isStaleZeroShopDisplayOverride(override, real);
}
