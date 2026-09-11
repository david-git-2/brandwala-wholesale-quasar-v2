import type { ShopCatalogItem, ShopCatalogPrice, ShopType } from '../types';

export function coerceCatalogPrice(value: unknown): ShopCatalogPrice | null {
  if (value == null || value === '') return null;

  if (typeof value === 'number') {
    return Number.isFinite(value)
      ? { amount: value, currency_id: null, code: null, symbol: null }
      : null;
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith('{')) {
      try {
        return coerceCatalogPrice(JSON.parse(trimmed) as unknown);
      } catch {
        return null;
      }
    }
    const amount = Number(trimmed);
    return Number.isFinite(amount)
      ? { amount, currency_id: null, code: null, symbol: null }
      : null;
  }

  if (typeof value !== 'object') return null;

  const rec = value as Record<string, unknown>;
  const rawAmount = rec.amount ?? rec.unit_price_amount ?? rec.sell_price_amount;
  if (rawAmount == null || rawAmount === '') return null;
  const amount = Number(rawAmount);
  if (!Number.isFinite(amount)) return null;

  const code = typeof rec.code === 'string' ? rec.code : null;
  const symbol = typeof rec.symbol === 'string' ? rec.symbol : code;

  return {
    amount,
    currency_id: typeof rec.currency_id === 'number' ? rec.currency_id : null,
    code,
    symbol,
  };
}

export function catalogPriceAmount(
  price: ShopCatalogPrice | null | undefined,
): number | null {
  return coerceCatalogPrice(price)?.amount ?? null;
}

export function formatCatalogPrice(
  price: ShopCatalogPrice | null | undefined,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  const coerced = coerceCatalogPrice(price);
  if (!coerced || coerced.amount == null) return null;
  return formatMoney(coerced.amount, coerced.symbol ?? coerced.code);
}

export function hasCatalogPrice(price: ShopCatalogPrice | null | undefined): boolean {
  return catalogPriceAmount(price) != null;
}

/** True when a price should be shown on a card (excludes zero placeholders). */
export function hasDisplayableCatalogPrice(price: ShopCatalogPrice | null | undefined): boolean {
  const amount = catalogPriceAmount(price);
  return amount != null && amount > 0;
}

type CatalogPriceFields = Pick<
  ShopCatalogItem,
  'unit_price' | 'sell_price' | 'resell_minimum_price'
> & {
  unit_price_amount?: number | string | null;
  unit_price_currency_id?: number | null;
  unit_price_currency_code?: string | null;
  unit_price_currency_symbol?: string | null;
  sell_price_amount?: number | string | null;
  sell_price_currency_id?: number | null;
  sell_price_currency_code?: string | null;
  sell_price_currency_symbol?: string | null;
};

function buildFlatCatalogPrice(
  flatAmount?: number | string | null,
  flatCurrencyId?: number | null,
  flatCode?: string | null,
  flatSymbol?: string | null,
): ShopCatalogPrice | null {
  if (flatAmount == null || flatAmount === '') return null;
  const amount = Number(flatAmount);
  if (!Number.isFinite(amount)) return null;

  return {
    amount,
    currency_id: flatCurrencyId ?? null,
    code: flatCode ?? null,
    symbol: flatSymbol ?? null,
  };
}

function resolveNestedOrFlatPrice(
  nested: ShopCatalogPrice | null | undefined,
  flatAmount?: number | string | null,
  flatCurrencyId?: number | null,
  flatCode?: string | null,
  flatSymbol?: string | null,
): ShopCatalogPrice | null {
  const flatPrice = buildFlatCatalogPrice(
    flatAmount,
    flatCurrencyId,
    flatCode,
    flatSymbol,
  );

  if (nested != null) {
    const amount = catalogPriceAmount(nested);
    if (amount != null) {
      return { ...nested, amount };
    }
    return flatPrice ?? nested;
  }

  return flatPrice;
}

export function normalizeShopCatalogItem<T extends CatalogPriceFields>(item: T): T {
  return {
    ...item,
    unit_price: resolveNestedOrFlatPrice(
      item.unit_price,
      item.unit_price_amount,
      item.unit_price_currency_id,
      item.unit_price_currency_code,
      item.unit_price_currency_symbol,
    ),
    sell_price: resolveNestedOrFlatPrice(
      item.sell_price,
      item.sell_price_amount,
      item.sell_price_currency_id,
      item.sell_price_currency_code,
      item.sell_price_currency_symbol,
    ),
  };
}

export function hasVendorCatalogListPrice(item: CatalogPriceFields): boolean {
  const normalized = normalizeShopCatalogItem(item);
  if (hasDisplayableCatalogPrice(normalized.unit_price)) return true;
  if (item.unit_price_amount == null || item.unit_price_amount === '') return false;
  const amount = Number(item.unit_price_amount);
  return Number.isFinite(amount) && amount > 0;
}

export function formatDropshipSellPrice(
  item: CatalogPriceFields,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  const normalized = normalizeShopCatalogItem(item);
  if (!hasDisplayableCatalogPrice(normalized.sell_price)) return null;
  return formatCatalogPrice(normalized.sell_price, formatMoney);
}

export function formatDropshipResellMinimumPrice(
  item: CatalogPriceFields,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  const normalized = normalizeShopCatalogItem(item);
  if (!hasDisplayableCatalogPrice(normalized.resell_minimum_price)) return null;
  return formatCatalogPrice(normalized.resell_minimum_price, formatMoney);
}

export function formatDropshipWholesalePrice(
  item: CatalogPriceFields,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  const normalized = normalizeShopCatalogItem(item);
  if (!hasDisplayableCatalogPrice(normalized.unit_price)) return null;
  return formatCatalogPrice(normalized.unit_price, formatMoney);
}

export function formatVendorCatalogListPrice(
  item: CatalogPriceFields,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  if (!hasVendorCatalogListPrice(item)) return null;

  const normalized = normalizeShopCatalogItem(item);
  const fromNested = formatCatalogPrice(normalized.unit_price, formatMoney);
  if (fromNested) return fromNested;

  const flatAmount = item.unit_price_amount;
  if (flatAmount == null || flatAmount === '') return null;
  const amount = Number(flatAmount);
  if (!Number.isFinite(amount) || amount <= 0) return null;

  return formatMoney(
    amount,
    item.unit_price_currency_symbol ?? item.unit_price_currency_code ?? null,
  );
}

export function formatStorefrontCardPrice(
  item: CatalogPriceFields,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  const sell = coerceCatalogPrice(item.sell_price);
  if (sell && sell.amount > 0) {
    return formatMoney(sell.amount, sell.symbol ?? sell.code);
  }

  const unit = coerceCatalogPrice(item.unit_price) ?? buildFlatCatalogPrice(
    item.unit_price_amount,
    item.unit_price_currency_id,
    item.unit_price_currency_code,
    item.unit_price_currency_symbol,
  );
  if (unit && unit.amount > 0) {
    return formatMoney(unit.amount, unit.symbol ?? unit.code);
  }

  return null;
}

export function formatStorefrontCardMinPrice(
  item: CatalogPriceFields,
  formatMoney: (amount: unknown, symbol?: string | null) => string,
): string | null {
  const resell = coerceCatalogPrice(item.resell_minimum_price);
  if (!resell || resell.amount <= 0) return null;
  return formatMoney(resell.amount, resell.symbol ?? resell.code);
}

export function storefrontCardPriceLabelKey(item: CatalogPriceFields): string | null {
  const sell = coerceCatalogPrice(item.sell_price);
  if (sell && sell.amount > 0) return 'shop.sell_price';
  const unit = coerceCatalogPrice(item.unit_price);
  if (unit && unit.amount > 0) return 'shop.unit_price';
  return null;
}

export function customerCanSeeCatalogPrice(
  shopType: ShopType | null | undefined,
  permissions?: {
    can_see_buy_price?: boolean;
    can_see_sell_price?: boolean;
  } | null,
): boolean {
  if (shopType === 'fixed_price') return !!permissions?.can_see_sell_price;
  if (shopType === 'vendor_catalog') {
    return !!permissions?.can_see_buy_price;
  }
  return !!permissions?.can_see_buy_price;
}

/** Customer-facing cart/checkout line prices (catalog list vs shelf sell vs dropship). */
export function customerCanSeeCartLinePrices(
  shopType: ShopType | null | undefined,
  permissions?: {
    can_see_buy_price?: boolean;
    can_see_sell_price?: boolean;
  } | null,
): boolean {
  if (shopType === 'dropship') {
    return !!(permissions?.can_see_buy_price || permissions?.can_see_sell_price);
  }
  return customerCanSeeCatalogPrice(shopType, permissions);
}
