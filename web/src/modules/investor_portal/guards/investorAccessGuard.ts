import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  getTenantSlugFromPath,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';
import type { RouteLocationRaw } from 'vue-router';

type GuardRoute = {
  fullPath: string;
  params?: Record<string, unknown>;
};

export const createInvestorAccessGuard = ({ loginRoute }: { loginRoute: string }) => {
  return (to: GuardRoute) => {
    const authStore = useAuthStore();

    const hasInvestorPortal =
      authStore.scope === 'investor' &&
      authStore.isAuthenticated &&
      authStore.activeModuleKeys.includes('investor_portal') &&
      authStore.matchedRole === 'investor_portal';

    if (!hasInvestorPortal) {
      const tenantSlug =
        (typeof to.params?.tenantSlug === 'string' ? to.params.tenantSlug : null) ??
        getTenantSlugFromRoute(to) ??
        getTenantSlugFromPath(to.fullPath);

      return {
        name: loginRoute,
        params: tenantSlug ? { tenantSlug } : {},
        query: { redirect: to.fullPath },
      } satisfies RouteLocationRaw;
    }

    return true;
  };
};
