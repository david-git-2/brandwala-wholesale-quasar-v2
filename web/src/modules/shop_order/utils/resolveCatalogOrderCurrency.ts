import type { ShopOrder, ShopOrderItem } from '../types';

const DEFAULT_PURCHASE_SYMBOL = '£';
const DEFAULT_SELL_SYMBOL = '৳';

type PurchaseSymbolItem = Pick<
  ShopOrderItem,
  'cost_price_currency_symbol' | 'unit_list_price_currency_symbol'
>;

export function firstLinePurchaseCurrencySymbol(items: PurchaseSymbolItem[]): string | null {
  for (const item of items) {
    const sym =
      item.cost_price_currency_symbol?.trim() || item.unit_list_price_currency_symbol?.trim();
    if (sym) return sym;
  }
  return null;
}

/** Purchase / cargo / landed (pre-FX) totals — prefer line cost currency over shop snapshot. */
export function resolveCatalogPurchaseCurrencySymbol(
  order: Pick<ShopOrder, 'shop_buy_currency_symbol'> | null | undefined,
  items: PurchaseSymbolItem[] = [],
): string {
  return firstLinePurchaseCurrencySymbol(items) || order?.shop_buy_currency_symbol?.trim() || DEFAULT_PURCHASE_SYMBOL;
}

/** Customer offer / landed-after-FX totals. */
export function resolveCatalogSellCurrencySymbol(
  order: Pick<ShopOrder, 'shop_sell_currency_symbol'> | null | undefined,
): string {
  return order?.shop_sell_currency_symbol?.trim() || DEFAULT_SELL_SYMBOL;
}