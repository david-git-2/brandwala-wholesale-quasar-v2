import type { CustomerAccessibleShop } from '../repositories/shopOrderRepository';
import type { ShopType } from '../types';
import { shopTypeToPathSegment, type ShopTypePathSegment } from './shopRouteTypes';

const lastShopIdKey = (tenantId: number) => `shop:${tenantId}:lastShopId`;
const lastShopSlugKey = (tenantId: number) => `shop:${tenantId}:lastShopSlug`;

export function shopScopeBase(
  tenantSlug: string | null | undefined,
  shopTypePath?: ShopTypePathSegment | null,
) {
  const tenant = tenantSlug?.trim() ? tenantSlug.trim() : null;
  if (!tenant) {
    return shopTypePath ? `/shop/${shopTypePath}` : '/shop';
  }
  return shopTypePath ? `/shop/${tenant}/${shopTypePath}` : `/shop/${tenant}`;
}

export function shopHomePath(tenantSlug?: string | null) {
  return `/shop/${tenantSlug ?? ''}/dashboard`;
}

export function shopCatalogEntryPath(
  tenantSlug?: string | null,
  shopTypePath: ShopTypePathSegment = 'catalog',
) {
  return `${shopScopeBase(tenantSlug, shopTypePath)}/browse`;
}

export function customerShopTypeI18nKey(shopType: string) {
  if (shopType === 'vendor_catalog') return 'shop_admin.shop_type_customer_catalog';
  if (shopType === 'dropship') return 'shop_admin.shop_type_customer_dropship';
  return 'shop_admin.shop_type_customer_shop';
}

export function isFixedPriceCatalog(
  shopType: string | null | undefined,
  canNegotiate?: boolean | null,
): boolean {
  if (shopType === 'dropship') return false;
  if (shopType === 'vendor_catalog') return canNegotiate === false;
  return shopType === 'fixed_price';
}

export function shopCatalogPath(
  tenantSlug: string | null | undefined,
  shopSlug: string,
  query?: string | null,
  shopType?: ShopType | null,
) {
  const shopTypePath = shopTypeToPathSegment(shopType) ?? 'catalog';
  return {
    path: `${shopScopeBase(tenantSlug, shopTypePath)}/browse/${shopSlug}`,
    query: query ? { q: query } : {},
  };
}

export function shopCatalogProductPath(
  tenantSlug: string | null | undefined,
  shopSlug: string,
  productId: number | string,
  listingId?: number | null,
  shopType?: ShopType | null,
) {
  const shopTypePath = shopTypeToPathSegment(shopType) ?? 'catalog';
  return {
    name: 'shop-storefront-product-detail-page' as const,
    params: {
      tenantSlug: tenantSlug ?? '',
      shopType: shopTypePath,
      shopSlug,
      productId: String(productId),
    },
    query: listingId ? { listingId: String(listingId) } : {},
  };
}

export function shopCartPath(
  tenantSlug: string | null | undefined,
  shopId?: number | null,
  shopType?: ShopType | null,
) {
  const shopTypePath = shopTypeToPathSegment(shopType) ?? 'catalog';
  return {
    path: `${shopScopeBase(tenantSlug, shopTypePath)}/cart`,
    query: shopId ? { shopId: String(shopId) } : {},
  };
}

export function shopDropshipReviewPath(tenantSlug: string | null | undefined, shopId?: number | null) {
  return {
    path: `/shop/${tenantSlug ?? ''}/dropship/review`,
    query: shopId ? { shopId: String(shopId) } : {},
  };
}

export function shopDropshipDeliveryPath(
  tenantSlug: string | null | undefined,
  shopId?: number | null,
) {
  return {
    path: `/shop/${tenantSlug ?? ''}/dropship/delivery`,
    query: shopId ? { shopId: String(shopId) } : {},
  };
}

export function shopDropshipCheckoutPath(
  tenantSlug: string | null | undefined,
  shopId?: number | null,
) {
  return {
    path: `/shop/${tenantSlug ?? ''}/dropship/checkout`,
    query: shopId ? { shopId: String(shopId) } : {},
  };
}

function parseShopId(value: unknown): number | null {
  const raw = Array.isArray(value) ? value[0] : value;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : null;
}

export function resolveCartShopId(
  tenantId: number | null | undefined,
  carts: { shop_id: number; updated_at?: string }[],
  queryShopId?: unknown,
): number | null {
  const fromQuery = parseShopId(queryShopId);
  if (fromQuery) return fromQuery;
  if (carts.length === 0) return null;
  if (carts.length === 1) return carts[0]?.shop_id ?? null;

  const lastId = getLastVisitedShopId(tenantId);
  if (lastId) {
    const match = carts.find((cart) => String(cart.shop_id) === lastId);
    if (match) return match.shop_id;
  }

  const sorted = [...carts].sort((a, b) =>
    String(b.updated_at ?? '').localeCompare(String(a.updated_at ?? '')),
  );
  return sorted[0]?.shop_id ?? null;
}

export function rememberCatalogShop(tenantId: number, shop: { id: number; slug: string }) {
  localStorage.setItem(lastShopIdKey(tenantId), String(shop.id));
  localStorage.setItem(lastShopSlugKey(tenantId), shop.slug);
}

export function getLastVisitedShopId(tenantId: number | null | undefined): string | null {
  if (!tenantId) return null;
  return localStorage.getItem(lastShopIdKey(tenantId));
}

export function getLastVisitedShopSlug(tenantId: number | null | undefined): string | null {
  if (!tenantId) return null;
  return localStorage.getItem(lastShopSlugKey(tenantId));
}

export function resolveCatalogShop(
  tenantId: number | null | undefined,
  shops: CustomerAccessibleShop[],
  shopType?: ShopType | null,
): CustomerAccessibleShop | null {
  const typedShops =
    shopType != null ? shops.filter((shop) => shop.shop_type === shopType) : shops;
  if (typedShops.length === 0) return null;

  const lastId = getLastVisitedShopId(tenantId);
  if (lastId) {
    const byId = typedShops.find((shop) => String(shop.id) === lastId);
    if (byId) return byId;
  }

  const lastSlug = getLastVisitedShopSlug(tenantId);
  if (lastSlug) {
    const bySlug = typedShops.find((shop) => shop.slug === lastSlug);
    if (bySlug) return bySlug;
  }

  return typedShops[0] ?? null;
}

export function filterShopsByRouteType(
  shops: CustomerAccessibleShop[],
  shopTypePath: string | null | undefined,
): CustomerAccessibleShop[] {
  if (!shopTypePath) return shops;
  const path = shopTypePath.trim().toLowerCase();
  const map: Record<string, ShopType> = {
    catalog: 'vendor_catalog',
    stock: 'fixed_price',
    dropship: 'dropship',
  };
  const shopType = map[path];
  if (!shopType) return shops;
  return shops.filter((s) => s.shop_type === shopType);
}