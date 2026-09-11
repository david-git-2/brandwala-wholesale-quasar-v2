import type { CustomerShopPermissions } from '../composables/useCustomerShopPermissionsQuery';
import type { CartData, ShopCartItem } from '../repositories/shopCartRepository';
import type { ShopCatalogPrice, ShopType } from '../types';
import { customerCanSeeCartLinePrices } from './catalogPriceUtils';

type RawCartItem = Record<string, unknown> & {
  id: number;
  cart_id?: number;
  product_id: number;
  global_stock_id?: number | null;
  global_stock_allocation_id?: number | null;
  listing_id?: number | null;
  grade_tag_id?: number | null;
  quantity: number;
  minimum_quantity?: number | null;
  minimum_order_quantity?: number | null;
  name: string;
  image_url?: string | null;
  unit_list_price_amount?: number | null;
  unit_list_price_currency_id?: number | null;
  unit_sell_price_amount?: number | null;
  unit_sell_price_currency_id?: number | null;
  unit_minimum_sell_price_amount?: number | null;
  unit_minimum_sell_price_currency_id?: number | null;
  customer_sell_price_amount?: number | null;
  customer_sell_price_currency_id?: number | null;
  unit_price?: ShopCatalogPrice | null;
  sell_price?: ShopCatalogPrice | null;
  resell_minimum_price?: ShopCatalogPrice | null;
};

type RawCartPayload = {
  cart?: Record<string, unknown> & {
    can_see_buy_price_snapshot?: boolean;
    can_see_sell_price_snapshot?: boolean;
    shop_type?: ShopType;
  };
  items?: RawCartItem[];
  permissions?: CustomerShopPermissions | null;
};

function buildCartPrice(
  amount: number | string | null | undefined,
  currencyId: number | null | undefined,
  nested?: ShopCatalogPrice | null,
): ShopCatalogPrice | null {
  if (nested?.amount != null && Number.isFinite(Number(nested.amount))) {
    return {
      amount: Number(nested.amount),
      currency_id: nested.currency_id ?? currencyId ?? null,
      code: nested.code ?? null,
      symbol: nested.symbol ?? nested.code ?? null,
    };
  }

  if (amount == null || amount === '') {
    return null;
  }

  const parsed = Number(amount);
  if (!Number.isFinite(parsed)) {
    return null;
  }

  return {
    amount: parsed,
    currency_id: currencyId ?? null,
    code: nested?.code ?? null,
    symbol: nested?.symbol ?? nested?.code ?? null,
  };
}

function mapCartItem(
  raw: RawCartItem,
  shopType?: ShopType,
  permissions?: CustomerShopPermissions | null,
): ShopCartItem {
  const unitPrice = buildCartPrice(
    raw.unit_list_price_amount,
    raw.unit_list_price_currency_id,
    raw.unit_price,
  );
  const listingSellPrice = buildCartPrice(
    raw.unit_sell_price_amount,
    raw.unit_sell_price_currency_id,
    raw.sell_price,
  );
  const customerSellPrice = buildCartPrice(
    raw.customer_sell_price_amount,
    raw.customer_sell_price_currency_id,
    null,
  );
  const resellMinimumPrice = buildCartPrice(
    raw.unit_minimum_sell_price_amount,
    raw.unit_minimum_sell_price_currency_id,
    raw.resell_minimum_price,
  );

  const sellPrice =
    shopType === 'dropship'
      ? customerSellPrice ?? listingSellPrice
      : listingSellPrice ?? customerSellPrice;

  const canSeeLinePrices = customerCanSeeCartLinePrices(shopType, permissions);

  return {
    id: Number(raw.id),
    cart_id: Number(raw.cart_id ?? 0),
    product_id: Number(raw.product_id),
    global_stock_id: raw.global_stock_id == null ? null : Number(raw.global_stock_id),
    global_stock_allocation_id:
      raw.global_stock_allocation_id == null ? null : Number(raw.global_stock_allocation_id),
    listing_id: raw.listing_id == null ? null : Number(raw.listing_id),
    grade_tag_id: raw.grade_tag_id == null ? null : Number(raw.grade_tag_id),
    quantity: Number(raw.quantity ?? 0),
    minimum_quantity: Number(raw.minimum_quantity ?? 1),
    minimum_order_quantity:
      raw.minimum_order_quantity == null ? null : Number(raw.minimum_order_quantity),
    name: String(raw.name ?? ''),
    image_url: raw.image_url == null ? null : String(raw.image_url),
    unit_price: canSeeLinePrices ? unitPrice : null,
    sell_price: canSeeLinePrices ? sellPrice : null,
    resell_minimum_price: canSeeLinePrices ? resellMinimumPrice : null,
  };
}

function resolveCartPermissions(
  raw: RawCartPayload,
  permissions?: CustomerShopPermissions | null,
): CustomerShopPermissions | null {
  const cart = raw.cart;
  const merged: CustomerShopPermissions = {
    ...(raw.permissions ?? {}),
    ...(permissions ?? {}),
  };

  if (merged.can_see_buy_price == null && cart?.can_see_buy_price_snapshot != null) {
    merged.can_see_buy_price = Boolean(cart.can_see_buy_price_snapshot);
  }
  if (merged.can_see_sell_price == null && cart?.can_see_sell_price_snapshot != null) {
    merged.can_see_sell_price = Boolean(cart.can_see_sell_price_snapshot);
  }

  return Object.keys(merged).length > 0 ? merged : null;
}

export function normalizeCartResponse(
  raw: RawCartPayload,
  permissions?: CustomerShopPermissions | null,
): CartData {
  const cart = raw.cart ?? {};
  const shopType = cart.shop_type as ShopType | undefined;
  const resolvedPermissions = resolveCartPermissions(raw, permissions);

  return {
    cart: cart as CartData['cart'],
    items: (raw.items ?? []).map((item) => mapCartItem(item, shopType, resolvedPermissions)),
    permissions: resolvedPermissions,
  };
}
