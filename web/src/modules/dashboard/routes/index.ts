import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
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
    path: '/app/:tenantSlug?',
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
          requireTenantContext: true,
          validateAccess: ({ authStore, to }) => {
            if (!authStore.selectedTenant) {
              return { name: 'admin-tenant-list' }
            }

            const routeTenantSlug = getTenantSlugFromRoute(to)
            const selectedTenantSlug = authStore.selectedTenant.slug

            if (routeTenantSlug === selectedTenantSlug) {
              return true
            }

            return getAppRouteLocation(to, selectedTenantSlug)
          },
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
          requireTenantContext: true,
          allowedRoles: [
            'customer_admin',
            'customer_negotiator',
            'customer_staff',
          ],
          validateAccess: ({ authStore, to }) => {
            if (
              authStore.actorType !== 'customer_group_member' ||
              authStore.customerGroupId === null
            ) {
              return getShopLoginRouteLocation(to, {
                login_error: 'no_membership',
              })
            }

            const routeTenantSlug = getTenantSlugFromRoute(to)
            const sessionTenantSlug = authStore.tenantSlug

            if (!sessionTenantSlug) {
              return getShopLoginRouteLocation(to, {
                login_error: 'invalid_tenant',
              })
            }

            if (!routeTenantSlug) {
              return getShopDashboardRouteLocation({
                ...to,
                params: {
                  ...(to.params ?? {}),
                  tenantSlug: sessionTenantSlug,
                },
              })
            }

            if (routeTenantSlug === sessionTenantSlug) {
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
