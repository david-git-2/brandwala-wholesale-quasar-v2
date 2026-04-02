import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getShopDashboardRouteLocation,
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const dashboardRoutes: RouteRecordRaw[] = [
  {
    path: '/platform',
    component: () => import('layouts/PlatformLayout.vue'),
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
    children: [
      {
        path: 'dashboard',
        name: 'admin-dashboard',
        component: () => import('../pages/AdminDashboard.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
        }),
      },
    ],
  },
  {
    path: '/shop/:tenantSlug?',
    component: () => import('layouts/ShopLayout.vue'),
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
          allowedRoles: [
            'customer_admin',
            'customer_negotiator',
            'customer_staff',
          ],
          validateAccess: ({ authStore, to }) => {
            const routeTenantSlug = getTenantSlugFromRoute(to)
            const sessionTenantSlug = authStore.tenant?.slug ?? null

            if (!routeTenantSlug || !sessionTenantSlug || routeTenantSlug === sessionTenantSlug) {
              return true
            }

            return getShopDashboardRouteLocation({
              ...to,
              query: {
                tenant_slug: sessionTenantSlug,
              },
            })
          },
        }),
      },
    ],
  },
]

export default dashboardRoutes
