import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const productBasedCostingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/product-based-costing',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'product_based_costing',
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
        name: 'product-based-costing-page',
        component: () => import('../pages/ProductBasedCostingPage.vue'),
      },
      {
        path: ':id',
        name: 'product-based-costing-file-details-page',
        component: () => import('../pages/ProductBasedCostingFileDetailsPage.vue'),
        props: true,
      },
      {
  path: ':id/cart',
  name: 'product-based-costing-file-cart-page',
  component: () => import('../pages/ProductBasedCostingFileCartPage.vue'),
  props: true,
},
    ],
  },
]

export default productBasedCostingRoutes
