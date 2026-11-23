import { useAuthStore } from '../stores/authStore';
import {
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';
import type { LocationQueryRaw, RouteLocationRaw } from 'vue-router';

type ShopGuardRoute = {
  name?: string | symbol | null | undefined;
  fullPath: string;
  params?: Record<string, unknown> | undefined;
  query?: LocationQueryRaw | undefined;
};

export function validateShopTenantSlug({
  authStore,
  to,
}: {
  authStore: ReturnType<typeof useAuthStore>;
  to: ShopGuardRoute;
}): true | RouteLocationRaw {
  const sessionTenantSlug = authStore.tenantSlug;
  const routeTenantSlug = getTenantSlugFromRoute(to);

  if (!sessionTenantSlug) {
    return getShopLoginRouteLocation(to, {
      login_error: 'invalid_tenant',
    });
  }

  if (!routeTenantSlug) {
    return true;
  }

  if (routeTenantSlug === sessionTenantSlug) {
    return true;
  }

  return getShopLoginRouteLocation(to, {
    redirect: to.fullPath,
  });
}
