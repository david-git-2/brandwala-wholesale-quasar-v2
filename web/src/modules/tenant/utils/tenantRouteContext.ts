import type { LocationQueryRaw, RouteLocationRaw } from 'vue-router';

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
  const scopedMatch = normalizedPath.match(/^\/([^/]+)\/(shop|app|investor)(\/|$)/);

  if (scopedMatch?.[1]) {
    return normalizeRouteToken(scopedMatch[1]);
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
): RouteLocationRaw => {
  const tenantSlug = getTenantSlugFromRoute(route, tenantSlugOverride) ?? undefined;

  return {
    name: 'customer-login-page',
    params: tenantSlug ? { tenantSlug } : {},
    query: {
      ...extraQuery,
    },
  };
};

export const getShopSelectCompanyRouteLocation = (
  route: RouteLike,
  extraQuery?: Record<string, string>,
  tenantSlugOverride?: string | null,
): RouteLocationRaw => {
  const tenantSlug = getTenantSlugFromRoute(route, tenantSlugOverride) ?? undefined;

  return {
    name: 'shop-select-company-page',
    params: tenantSlug ? { tenantSlug } : {},
    query: {
      ...extraQuery,
    },
  };
};

export const getShopDashboardRouteLocation = (
  route: RouteLike,
  tenantSlugOverride?: string | null,
): RouteLocationRaw => {
  const tenantSlug =
    normalizeRouteToken(tenantSlugOverride) ?? getTenantSlugFromRoute(route) ?? undefined;

  return {
    name: 'customer-dashboard',
    params: tenantSlug ? { tenantSlug } : {},
  };
};

export const getAppRouteLocation = (
  route: RouteLike,
  selectedTenantSlug: string | null | undefined,
): RouteLocationRaw => {
  const tenantSlug = selectedTenantSlug ?? undefined;

  return {
    name: typeof route.name === 'string' ? route.name : undefined,
    params: {
      ...(route.params ?? {}),
      ...(tenantSlug ? { tenantSlug } : {}),
    },
    query: route.query ?? {},
  };
};
