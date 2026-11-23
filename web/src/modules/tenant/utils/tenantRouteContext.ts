import type { LocationQueryRaw, RouteLocationRaw } from 'vue-router';
import {
  isShopTypePathSegment,
  SHOP_TYPE_PATH_SEGMENTS,
  type ShopTypePathSegment,
} from 'src/modules/shop_order/utils/shopRouteTypes';

type RouteLike = {
  fullPath?: string;
  name?: string | symbol | null | undefined;
  params?: Record<string, unknown> | undefined;
  query?: LocationQueryRaw | undefined;
};

const normalizeRouteToken = (value: unknown): string | null => {
  const rawValue = Array.isArray(value) ? value[0] : value;

  if (typeof rawValue !== 'string') {
    return null;
  }

  const normalizedValue = rawValue.trim().toLowerCase();

  return normalizedValue || null;
};

const normalizeHostname = (value: string | null | undefined): string | null => {
  const normalizedValue = value?.trim().toLowerCase() ?? '';

  return normalizedValue || null;
};

const isLocalHostname = (hostname: string | null) =>
  hostname === null ||
  hostname === 'localhost' ||
  hostname === '127.0.0.1' ||
  hostname === '0.0.0.0';

export const getTenantSlugFromPath = (path: string): string | null => {
  const normalizedPath = path.split('?')[0]?.split('#')[0] ?? path;

  const shopReserved = new Set(['login', 'select-company', ...SHOP_TYPE_PATH_SEGMENTS]);
  const shopTenantMatch = normalizedPath.match(/^\/shop\/([^/]+)(\/|$)/);
  if (shopTenantMatch?.[1]) {
    const shopCandidate = normalizeRouteToken(shopTenantMatch[1]);
    if (shopCandidate && !shopReserved.has(shopCandidate)) {
      return shopCandidate;
    }
  }

  const scopedMatch = normalizedPath.match(/^\/([^/]+)\/(shop|app|investor)(\/|$)/);
  if (scopedMatch?.[1]) {
    const first = normalizeRouteToken(scopedMatch[1]);
    if (first === 'app' || first === 'shop' || first === 'investor' || first === 'platform') {
      return null;
    }
    return first;
  }

  return null;
};

export const getScopeFromPath = (
  path: string,
): 'platform' | 'app' | 'shop' | 'investor' | null => {
  const normalizedPath = path.split('?')[0]?.split('#')[0] ?? path;

  if (/^\/platform(\/|$)/.test(normalizedPath)) {
    return 'platform';
  }

  const scopedMatch = normalizedPath.match(/^\/([^/]+)\/(shop|app|investor)(\/|$)/);
  if (scopedMatch?.[2] === 'shop') return 'shop';
  if (scopedMatch?.[2] === 'investor') return 'investor';
  if (scopedMatch?.[2] === 'app') return 'app';
  if (/^\/shop(\/|$)/.test(normalizedPath)) return 'shop';
  if (/^\/investor(\/|$)/.test(normalizedPath)) return 'investor';
  if (/^\/app(\/|$)/.test(normalizedPath)) return 'app';

  return null;
};

export const getTenantSlugFromRoute = (
  route: RouteLike,
  tenantSlugOverride?: string | null,
): string | null => {
  const fromOverride = normalizeRouteToken(tenantSlugOverride);
  if (fromOverride) {
    return fromOverride;
  }

  const fromParams =
    normalizeRouteToken(route.params?.tenantSlug) ?? normalizeRouteToken(route.query?.tenant_slug);
  if (fromParams) {
    return fromParams;
  }

  const redirectPath =
    typeof route.query?.redirect === 'string' ? route.query.redirect.trim() : '';
  if (redirectPath) {
    const fromRedirect = getTenantSlugFromPath(redirectPath);
    if (fromRedirect) {
      return fromRedirect;
    }
  }

  if (route.fullPath) {
    const fromFullPath = getTenantSlugFromPath(route.fullPath);
    if (fromFullPath) {
      return fromFullPath;
    }
  }

  return null;
};

const shopTypeFromPathString = (path: string): ShopTypePathSegment | null => {
  const normalizedPath = path.split('?')[0]?.split('#')[0] ?? path;
  const match = normalizedPath.match(/^\/shop\/[^/]+\/(catalog|stock|dropship)(\/|$)/);
  const candidate = normalizeRouteToken(match?.[1]);
  if (candidate && isShopTypePathSegment(candidate)) {
    return candidate;
  }
  return null;
};

export const getShopTypePathFromRoute = (
  route: RouteLike,
  shopTypeOverride?: string | null,
): ShopTypePathSegment | null => {
  const fromOverride = normalizeRouteToken(shopTypeOverride);
  if (fromOverride && isShopTypePathSegment(fromOverride)) {
    return fromOverride;
  }

  const fromParams = normalizeRouteToken(route.params?.shopType);
  if (fromParams && isShopTypePathSegment(fromParams)) {
    return fromParams;
  }

  const fromQuery = normalizeRouteToken(route.query?.shop_type);
  if (fromQuery && isShopTypePathSegment(fromQuery)) {
    return fromQuery;
  }

  const redirectPath =
    typeof route.query?.redirect === 'string' ? route.query.redirect.trim() : '';
  if (redirectPath) {
    const fromRedirect = shopTypeFromPathString(redirectPath);
    if (fromRedirect) {
      return fromRedirect;
    }
  }

  if (route.fullPath) {
    const fromFullPath = shopTypeFromPathString(route.fullPath);
    if (fromFullPath) {
      return fromFullPath;
    }
  }

  return null;
};

export const getTenantHostnameForEntry = (): string | null => {
  if (typeof window === 'undefined') {
    return null;
  }

  const hostname = normalizeHostname(window.location.hostname);

  if (isLocalHostname(hostname)) {
    return null;
  }

  return hostname;
};

export const getTenantLookupFromRoute = (route: RouteLike) => {
  const tenantSlug = getTenantSlugFromRoute(route);
  const hostname = getTenantHostnameForEntry();

  if (tenantSlug) {
    return {
      tenantSlug,
      hostname,
      source: 'slug' as const,
    };
  }

  if (hostname) {
    return {
      tenantSlug: null,
      hostname,
      source: 'public_domain' as const,
    };
  }

  return {
    tenantSlug: null,
    hostname: null,
    source: null,
  };
};

export const getShopLoginRouteLocation = (
  route: RouteLike,
  extraQuery?: Record<string, string>,
  tenantSlugOverride?: string | null,
  shopTypeOverride?: string | null,
): RouteLocationRaw => {
  const tenantSlug = getTenantSlugFromRoute(route, tenantSlugOverride) ?? undefined;
  const shopType = getShopTypePathFromRoute(route, shopTypeOverride) ?? undefined;

  if (!tenantSlug) {
    return {
      path: '/shop/login',
      query: { ...extraQuery },
    };
  }

  if (shopType) {
    return {
      name: 'customer-login-page',
      params: { tenantSlug, shopType },
      query: {
        ...extraQuery,
      },
    };
  }

  return {
    path: `/shop/${tenantSlug}/login`,
    query: { ...extraQuery },
  };
};

export const getShopSelectCompanyRouteLocation = (
  route: RouteLike,
  extraQuery?: Record<string, string>,
  tenantSlugOverride?: string | null,
  shopTypeOverride?: string | null,
): RouteLocationRaw => {
  const tenantSlug = getTenantSlugFromRoute(route, tenantSlugOverride) ?? undefined;
  const shopType = getShopTypePathFromRoute(route, shopTypeOverride) ?? undefined;

  if (tenantSlug && shopType) {
    return {
      name: 'shop-select-company-page',
      params: { tenantSlug, shopType },
      query: {
        ...extraQuery,
      },
    };
  }

  return {
    path: `/shop/${tenantSlug ?? ''}/select-company`,
    query: { ...extraQuery },
  };
};

export const getShopDashboardRouteLocation = (
  route: RouteLike,
  tenantSlugOverride?: string | null,
  shopTypeOverride?: string | null,
): RouteLocationRaw => {
  const tenantSlug =
    normalizeRouteToken(tenantSlugOverride) ?? getTenantSlugFromRoute(route) ?? '';
  const shopType = getShopTypePathFromRoute(route, shopTypeOverride) ?? 'catalog';

  return {
    name: 'customer-dashboard',
    params: { tenantSlug, shopType },
  };
};

export const getInvestorLoginRouteLocation = (
  _route: RouteLike,
  extraQuery?: Record<string, string>,
  _tenantSlugOverride?: string | null,
): RouteLocationRaw => {
  return {
    name: 'investor-login-page',
    query: {
      ...extraQuery,
    },
  };
};

export const getInvestorDashboardRouteLocation = (
  _route: RouteLike,
  _tenantSlugOverride?: string | null,
): RouteLocationRaw => {
  return {
    name: 'investor-dashboard-page',
  };
};

export const getAppRouteLocation = (
  route: RouteLike,
  _selectedTenantSlug?: string | null | undefined,
): RouteLocationRaw => {
  const params = { ...(route.params ?? {}) };
  delete params.tenantSlug;

  return {
    name: typeof route.name === 'string' ? route.name : undefined,
    params: params as Record<string, string | number | (string | number)[]>,
    query: route.query ?? {},
  };
};

/** App desk: session/header is tenant truth; missing URL slug is OK. */
export const validateAppRouteTenantSlug = ({
  authStore,
  to,
}: {
  authStore: { selectedTenant?: { slug: string } | null };
  to: RouteLike;
}): true => {
  void authStore;
  void to;
  return true;
};
