import type { DropshipCartData, DropshipCartItem, DropshipCartTotals } from '../repositories/dropshipCartRepository';
import type { ShopCatalogPrice } from '../types';
import { resolveShopCartItemMoq } from './cartQuantityUtils';

type RawCatalogCartItem = {
  id: number;
  product_id: number;
  global_stock_id?: number | null;
  quantity: number;
  minimum_quantity?: number | null;
  minimum_order_quantity?: number | null;
  unit_sell_price_amount?: number | null;
  unit_sell_price_currency_id?: number | null;
  unit_minimum_sell_price_amount?: number | null;
  unit_minimum_sell_price_currency_id?: number | null;
  customer_sell_price_amount?: number | null;
  customer_sell_price_currency_id?: number | null;
  name: string;
  image_url?: string | null;
};

function priceFromRaw(
  amount: number | null | undefined,
  currencyId: number | null | undefined,
  fallback?: ShopCatalogPrice | null,
): ShopCatalogPrice {
  return {
    amount: amount ?? null,
    currency_id: currencyId ?? fallback?.currency_id ?? null,
    code: fallback?.code ?? null,
    symbol: fallback?.symbol ?? null,
  };
}

function mapRawItemToDropshipItem(
  raw: RawCatalogCartItem,
  previous?: DropshipCartItem,
): DropshipCartItem {
  const sellAmount = Number(raw.unit_sell_price_amount ?? 0);
  const resellAmount = Number(raw.customer_sell_price_amount ?? raw.unit_sell_price_amount ?? 0);
  const minResellAmount = Number(raw.unit_minimum_sell_price_amount ?? 0);
  const quantity = Number(raw.quantity ?? 0);
  const moq = resolveShopCartItemMoq(raw, { dropship: true });

  const listingSellPrice = priceFromRaw(
    sellAmount,
    raw.unit_sell_price_currency_id,
    previous?.listing_sell_price ?? previous?.purchase_price,
  );

  return {
    id: raw.id,
    product_id: raw.product_id,
    global_stock_id: raw.global_stock_id ?? null,
    name: raw.name,
    image_url: raw.image_url ?? null,
    quantity,
    minimum_quantity: moq,
    minimum_order_quantity: moq,
    purchase_price: listingSellPrice,
    listing_sell_price: listingSellPrice,
    resell_price: priceFromRaw(
      resellAmount,
      raw.customer_sell_price_currency_id ?? raw.unit_sell_price_currency_id,
      previous?.resell_price,
    ),
    min_resell_price: priceFromRaw(
      minResellAmount,
      raw.unit_minimum_sell_price_currency_id,
      previous?.min_resell_price,
    ),
    line_totals: {
      purchase_subtotal: quantity * sellAmount,
      resell_subtotal: quantity * resellAmount,
    },
    is_resell_below_floor: minResellAmount > 0 && resellAmount < minResellAmount,
  };
}

export function computeDropshipCartTotals(items: DropshipCartItem[]): DropshipCartTotals {
  return items.reduce<DropshipCartTotals>(
    (acc, item) => ({
      item_count: acc.item_count + item.quantity,
      line_count: acc.line_count + 1,
      purchase_subtotal: acc.purchase_subtotal + item.line_totals.purchase_subtotal,
      resell_subtotal: acc.resell_subtotal + item.line_totals.resell_subtotal,
      estimated_profit:
        acc.estimated_profit +
        (item.line_totals.resell_subtotal - item.line_totals.purchase_subtotal),
    }),
    {
      item_count: 0,
      line_count: 0,
      purchase_subtotal: 0,
      resell_subtotal: 0,
      estimated_profit: 0,
    },
  );
}

export function mergeDropshipCartFromCatalogResponse(
  previous: DropshipCartData | null | undefined,
  catalogResponse: { cart?: { updated_at?: string }; items?: RawCatalogCartItem[] } | null | undefined,
): DropshipCartData | null {
  if (!previous || !catalogResponse?.items) return previous ?? null;

  const previousItemsById = new Map(previous.items.map((item) => [item.id, item]));
  const items = catalogResponse.items.map((raw) =>
    mapRawItemToDropshipItem(raw, previousItemsById.get(raw.id)),
  );

  return {
    ...previous,
    cart: {
      ...previous.cart,
      updated_at: catalogResponse.cart?.updated_at ?? previous.cart.updated_at,
    },
    items,
    totals: computeDropshipCartTotals(items),
  };
}
