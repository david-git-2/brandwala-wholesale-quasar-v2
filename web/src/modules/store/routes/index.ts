import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const storeRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/stores',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin'],
      requireTenantContext: true,
      requiredModule: 'store',
      validateAccess: ({ authStore, to }) => {
        const selectedTenantSlug = authStore.selectedTenant?.slug ?? null

        if (!selectedTenantSlug) {
          return true
        }

        const routeTenantSlug = getTenantSlugFromRoute(to)

        if (routeTenantSlug === selectedTenantSlug) {
          return true
        }

        return getAppRouteLocation(to, selectedTenantSlug)
      },
    }),
    children: [
      {
        path: '',
        name: 'app-store-page',
        component: () => import('../pages/AdminStorePage.vue'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/shop/stores',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-store-page',
        component: () => import('../pages/CustomerStorePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'store',
        }),
      },
    ],
  },
]

export default storeRoutes
