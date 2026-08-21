import { createAccessGuard, type AccessRole } from './accessGuard';
import { validateShopTenantSlug } from './validateShopTenantSlug';
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';
import type { ModuleKey } from 'src/modules/navigation/modulePermissions';

const SHOP_CUSTOMER_ROLES: AccessRole[] = [
  'customer_admin',
  'customer_negotiator',
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
    allowedRoles: SHOP_CUSTOMER_ROLES,
    ...(opts.requiredModule ? { requiredModule: opts.requiredModule } : {}),
    validateAccess: validateShopTenantSlug,
  });
}
