import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { validateShopTenantSlug } from 'src/modules/auth/guards/validateShopTenantSlug';
import {
  getShopDashboardRouteLocation,
  getShopLoginRouteLocation,
  getShopSelectCompanyRouteLocation,
  validateAppRouteTenantSlug,
} from 'src/modules/tenant/utils/tenantRouteContext';

const dashboardRoutes: RouteRecordRaw[] = [
  {
    path: '/platform',
    component: () => import('layouts/PlatformLayout.vue'),
    redirect: '/platform/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'superadmin-dashboard',
        component: () => import('../pages/SuperadminDashboard.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'superadmin-login-page',
          requiredScope: 'platform',
          allowedRoles: ['superadmin'],
        }),
      },
    ],
  },
  {
    path: '/app',
    component: () => import('layouts/AppLayout.vue'),
    redirect: '/app/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'admin-dashboard',
        component: () => import('../pages/AdminDashboard.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          validateAccess: ({ authStore, to }) => {
            if (!authStore.selectedTenant) {
              return { name: 'admin-tenant-list' };
            }
            return validateAppRouteTenantSlug({ authStore, to });
          },
        }),
      },
    ],
  },
  {
    path: '/shop/:tenantSlug',
    component: () => import('layouts/ShopLayout.vue'),
    redirect: (to) => `/shop/${String(to.params.tenantSlug ?? '')}/dashboard`,
    children: [
      {
        path: 'dashboard',
        name: 'customer-dashboard',
        component: () => import('../pages/CustomerDashboard.vue'),
        beforeEnter: createAccessGuard({
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

            const routeTenantSlug = typeof to.params?.tenantSlug === 'string' ? to.params.tenantSlug : null;
            if (!routeTenantSlug && authStore.tenantSlug) {
              return getShopDashboardRouteLocation(to, authStore.tenantSlug);
            }

            return true;
          },
        }),
      },
    ],
  },
];

export default dashboardRoutes;