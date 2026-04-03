import type { LocationQueryRaw, RouteLocationRaw } from 'vue-router'

type RouteLike = {
  fullPath?: string
  name?: string | symbol | null | undefined
  params?: Record<string, unknown> | undefined
  query?: LocationQueryRaw | undefined
}

const normalizeRouteToken = (value: unknown): string | null => {
  const rawValue = Array.isArray(value) ? value[0] : value

  if (typeof rawValue !== 'string') {
    return null
  }

  const normalizedValue = rawValue.trim().toLowerCase()

  return normalizedValue || null
}

const normalizeHostname = (value: string | null | undefined): string | null => {
  const normalizedValue = value?.trim().toLowerCase() ?? ''

  return normalizedValue || null
}

const isLocalHostname = (hostname: string | null) =>
  hostname === null ||
  hostname === 'localhost' ||
  hostname === '127.0.0.1' ||
  hostname === '0.0.0.0'

export const getTenantSlugFromRoute = (route: RouteLike): string | null =>
  normalizeRouteToken(route.params?.tenantSlug) ??
  normalizeRouteToken(route.query?.tenant_slug)

export const getTenantHostnameForEntry = (): string | null => {
  if (typeof window === 'undefined') {
    return null
  }

  const hostname = normalizeHostname(window.location.hostname)

  if (isLocalHostname(hostname)) {
    return null
  }

  return hostname
}

export const getTenantLookupFromRoute = (route: RouteLike) => {
  const tenantSlug = getTenantSlugFromRoute(route)
  const hostname = getTenantHostnameForEntry()

  if (tenantSlug) {
    return {
      tenantSlug,
      hostname,
      source: 'slug' as const,
    }
  }

  if (hostname) {
    return {
      tenantSlug: null,
      hostname,
      source: 'public_domain' as const,
    }
  }

  return {
    tenantSlug: null,
    hostname: null,
    source: null,
  }
}

export const getShopLoginRouteLocation = (
  route: RouteLike,
  extraQuery?: Record<string, string>,
): RouteLocationRaw => {
  const tenantSlug = getTenantSlugFromRoute(route) ?? undefined

  return {
    name: 'customer-login-page',
    params: tenantSlug ? { tenantSlug } : {},
    query: {
      ...extraQuery,
    },
  }
}

export const getShopDashboardRouteLocation = (route: RouteLike): RouteLocationRaw => {
  const tenantSlug = getTenantSlugFromRoute(route) ?? undefined

  return {
    name: 'customer-dashboard',
    params: tenantSlug ? { tenantSlug } : {},
  }
}

export const getAppRouteLocation = (
  route: RouteLike,
  selectedTenantSlug: string | null | undefined,
): RouteLocationRaw => {
  const tenantSlug = selectedTenantSlug ?? undefined

  return {
    name: typeof route.name === 'string' ? route.name : undefined,
    params: {
      ...(route.params ?? {}),
      ...(tenantSlug ? { tenantSlug } : {}),
    },
    query: route.query ?? {},
  }
}
