import type { ShopCatalogPrice } from '../types';

export function formatCatalogPrice(
  price: ShopCatalogPrice | null | undefined,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  if (!price || price.amount == null) return null;
  return formatMoney(price.amount, price.symbol ?? price.code);
}

export function hasCatalogPrice(price: ShopCatalogPrice | null | undefined): boolean {
  return price?.amount != null;
}
