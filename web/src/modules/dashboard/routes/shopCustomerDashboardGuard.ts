import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { validateShopTenantSlug } from 'src/modules/auth/guards/validateShopTenantSlug';
import { getLastShopTypePath } from 'src/modules/shop_order/utils/catalogShop';
import {
  getShopDashboardRouteLocation,
  getShopLoginRouteLocation,
  getShopSelectCompanyRouteLocation,
  getShopTypePathFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

export const shopCustomerDashboardGuard = createAccessGuard({
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
  allowedRoles: ['customer_admin', 'customer_manager', 'customer_staff'],
  validateAccess: ({ authStore, to }) => {
    if (authStore.actorType !== 'customer_group_member') {
      return getShopLoginRouteLocation(to, {
        login_error: 'no_membership',
      });
    }

    const slugCheck = validateShopTenantSlug({ authStore, to });
    if (slugCheck !== true) {
      return slugCheck;
    }

    const routeTenantSlug =
      typeof to.params?.tenantSlug === 'string' ? to.params.tenantSlug : null;
    const routeShopType = getShopTypePathFromRoute(to);

    if (!routeTenantSlug && authStore.tenantSlug) {
      return getShopDashboardRouteLocation(
        to,
        authStore.tenantSlug,
        getLastShopTypePath(authStore.tenantId),
      );
    }

    if (routeTenantSlug && !routeShopType) {
      return getShopDashboardRouteLocation(
        to,
        routeTenantSlug,
        getLastShopTypePath(authStore.tenantId),
      );
    }

    return true;
  },
});