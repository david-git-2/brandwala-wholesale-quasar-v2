import type { CustomerAccessibleShop } from '../repositories/shopOrderRepository';

const lastShopIdKey = (tenantId: number) => `shop:${tenantId}:lastShopId`;
const lastShopSlugKey = (tenantId: number) => `shop:${tenantId}:lastShopSlug`;

export function shopScopeBase(tenantSlug?: string | null) {
  return tenantSlug ? `/${tenantSlug}/shop` : '/shop';
}

export function shopHomePath(tenantSlug?: string | null) {
  return `${shopScopeBase(tenantSlug)}/dashboard`;
}

export function shopCatalogEntryPath(tenantSlug?: string | null) {
  return `${shopScopeBase(tenantSlug)}/browse`;
}

export function customerShopTypeI18nKey(shopType: string) {
  if (shopType === 'vendor_catalog') return 'shop_admin.shop_type_customer_catalog';
  if (shopType === 'dropship') return 'shop_admin.shop_type_customer_dropship';
  return 'shop_admin.shop_type_customer_shop';
}

export function shopCatalogPath(
  tenantSlug: string | null | undefined,
  shopSlug: string,
  query?: string | null,
) {
  return {
    path: `${shopScopeBase(tenantSlug)}/browse/${shopSlug}`,
    query: query ? { q: query } : {},
  };
}

export function shopCatalogProductPath(
  tenantSlug: string | null | undefined,
  shopSlug: string,
  productId: number | string,
) {
  return {
    name: 'shop-storefront-product-detail-page' as const,
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      shopSlug,
      productId: String(productId),
    },
  };
}

export function shopCartPath(
  tenantSlug: string | null | undefined,
  shopId?: number | null,
) {
  return {
    path: `${shopScopeBase(tenantSlug)}/cart`,
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
): CustomerAccessibleShop | null {
  if (shops.length === 0) return null;

  const lastId = getLastVisitedShopId(tenantId);
  if (lastId) {
    const byId = shops.find((shop) => String(shop.id) === lastId);
    if (byId) return byId;
  }

  const lastSlug = getLastVisitedShopSlug(tenantId);
  if (lastSlug) {
    const bySlug = shops.find((shop) => shop.slug === lastSlug);
    if (bySlug) return bySlug;
  }

  return shops[0] ?? null;
}
