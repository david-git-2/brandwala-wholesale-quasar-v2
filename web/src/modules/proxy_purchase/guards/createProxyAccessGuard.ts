import {
  createAccessGuard,
  type AccessRole,
} from 'src/modules/workspace/submodules/auth/guards/accessGuard';
import {
  getProxyLoginRouteLocation,
  getProxySelectGroupRouteLocation,
} from 'src/modules/tenant/utils/tenantRouteContext';

const PROXY_PORTAL_ROLES: AccessRole[] = [
  'proxy_customer_admin',
  'proxy_customer_staff',
  'proxy_supplier_admin',
  'proxy_supplier_staff',
];

export const createProxyAccessGuard = () =>
  createAccessGuard({
    loginRoute: (to) => getProxyLoginRouteLocation(to, { redirect: to.fullPath }),
    requiredScope: 'proxy',
    requireTenantContext: true,
    requireCustomerGroup: true,
    missingCustomerGroupRoute: (to) =>
      getProxySelectGroupRouteLocation(to, { redirect: to.fullPath }),
    allowedRoles: PROXY_PORTAL_ROLES,
  });