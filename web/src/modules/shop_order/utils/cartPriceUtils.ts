import type { ShopCatalogPrice, ShopType } from '../types';
import type { ActiveCartItem, ShopCartItem } from '../repositories/shopCartRepository';

export function cartPriceAmount(price: ShopCatalogPrice | null | undefined): number {
  return Number(price?.amount ?? 0);
}

export function cartPriceSymbol(price: ShopCatalogPrice | null | undefined): string {
  return price?.symbol ?? price?.code ?? '৳';
}

export function getCartItemSellAmount(
  item: ShopCartItem,
  editedSellPrice?: number,
): number {
  if (editedSellPrice !== undefined) return editedSellPrice;
  return cartPriceAmount(item.sell_price);
}

export function getCartItemBuyAmount(item: ShopCartItem): number {
  return cartPriceAmount(item.unit_price);
}

export function getCartItemMinSellAmount(item: ShopCartItem): number {
  return cartPriceAmount(item.resell_minimum_price);
}

/** Customer-facing line unit price (catalog list / shelf sell / dropship recipient). */
export function getCartDisplayUnitAmount(
  shopType: ShopType | undefined,
  item: ShopCartItem,
  editedSellPrice?: number,
): number {
  if (shopType === 'vendor_catalog') {
    return getCartItemBuyAmount(item);
  }
  return getCartItemSellAmount(item, editedSellPrice);
}

export function getCartLineSubtotalAmount(
  shopType: ShopType | undefined,
  item: ShopCartItem,
  qty: number,
  editedSellPrice?: number,
): number {
  return getCartDisplayUnitAmount(shopType, item, editedSellPrice) * qty;
}

export function getCartLineBuyerSubtotalAmount(
  shopType: ShopType | undefined,
  item: ShopCartItem,
  qty: number,
): number {
  if (shopType === 'dropship' || shopType === 'vendor_catalog') {
    return getCartItemBuyAmount(item) * qty;
  }
  return getCartItemSellAmount(item) * qty;
}

export function sumCartSubtotal(
  shopType: ShopType | undefined,
  items: ShopCartItem[],
  getQty: (item: ShopCartItem) => number = (i) => i.quantity,
  editedSellPrices?: Record<number, number>,
): number {
  return items.reduce((sum, item) => {
    const edited = editedSellPrices?.[item.id];
    return sum + getCartLineSubtotalAmount(shopType, item, getQty(item), edited);
  }, 0);
}

export function sumCartBuyerSubtotal(
  shopType: ShopType | undefined,
  items: ShopCartItem[],
  getQty: (item: ShopCartItem) => number = (i) => i.quantity,
): number {
  return items.reduce(
    (sum, item) => sum + getCartLineBuyerSubtotalAmount(shopType, item, getQty(item)),
    0,
  );
}

export function resolveCartCurrencySymbol(
  items: ShopCartItem[],
  activeCart?: ActiveCartItem | null,
): string {
  if (activeCart?.currency_symbol) return activeCart.currency_symbol;
  if (activeCart?.currency_code) return activeCart.currency_code;
  for (const item of items) {
    for (const p of [item.sell_price, item.unit_price, item.resell_minimum_price]) {
      if (p?.symbol) return p.symbol;
      if (p?.code) return p.code;
    }
  }
  return '৳';
}

export function formatCartPriceAmount(
  amount: number,
  price?: ShopCatalogPrice | null,
  fallbackSymbol = '৳',
): string {
  const sym = price ? cartPriceSymbol(price) : fallbackSymbol;
  return `${sym}${Number(amount).toFixed(2)}`;
}

export function pickCartItemPriceForDisplay(
  shopType: ShopType | undefined,
  item: ShopCartItem,
): ShopCatalogPrice | null {
  if (shopType === 'vendor_catalog') return item.unit_price ?? null;
  return item.sell_price ?? item.unit_price ?? null;
}
