import { createAccessGuard, type AccessRole } from './accessGuard';
import { validateShopTenantSlug } from './validateShopTenantSlug';
import {
  getShopLoginRouteLocation,
  getShopSelectCompanyRouteLocation,
} from 'src/modules/tenant/utils/tenantRouteContext';
import type { ModuleKey } from 'src/modules/navigation/modulePermissions';
import { useAuthStore } from '../stores/authStore';
import type { LocationQueryRaw } from 'vue-router';

const SHOP_CUSTOMER_ROLES: AccessRole[] = [
  'customer_admin',
  'customer_manager',
  'customer_staff',
];

export function createShopAccessGuard(opts: { requiredModule?: ModuleKey } = {}) {
  return createAccessGuard({
    loginRoute: (to) =>
      getShopLoginRouteLocation(to, {
        redirect: to.fullPath,
      }),
    requiredScope: 'shop',
    requireTenantContext: true,
    requireCustomerGroup: true,
    missingCustomerGroupRoute: (to) =>
      getShopSelectCompanyRouteLocation(to, {
        redirect: to.fullPath,
      }),
    allowedRoles: SHOP_CUSTOMER_ROLES,
    ...(opts.requiredModule ? { requiredModule: opts.requiredModule } : {}),
    validateAccess: validateShopTenantSlug,
  });
}

export function createShopSelectCompanyGuard() {
  return (to: {
    fullPath: string;
    params?: Record<string, unknown>;
    query?: LocationQueryRaw;
  }) => {
    const authStore = useAuthStore();
    if (!authStore.isAuthenticated || authStore.scope !== 'shop' || !authStore.tenantId) {
      return getShopLoginRouteLocation(to, {
        redirect: to.fullPath,
      });
    }
    return true;
  };
}
