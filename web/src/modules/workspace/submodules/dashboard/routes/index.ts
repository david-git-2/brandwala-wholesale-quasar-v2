import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { validateAppRouteTenantSlug } from 'src/modules/tenant/utils/tenantRouteContext';
import { shopCustomerDashboardGuard } from './shopCustomerDashboardGuard';

const SHOP_TYPE = ':shopType(catalog|stock|dropship)';

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
    path: '/shop/:tenantSlug/dashboard',
    redirect: (to) =>
      `/shop/${String(to.params.tenantSlug ?? '')}/catalog/dashboard`,
  },
  {
    path: '/shop/:tenantSlug',
    redirect: (to) =>
      `/shop/${String(to.params.tenantSlug ?? '')}/catalog/dashboard`,
  },
  {
    path: `/shop/:tenantSlug/${SHOP_TYPE}/dashboard`,
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'customer-dashboard',
        component: () => import('../pages/CustomerDashboard.vue'),
        beforeEnter: shopCustomerDashboardGuard,
      },
    ],
  },
];

export default dashboardRoutes;