import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { getAppRouteLocation, getTenantSlugFromRoute } from 'src/modules/tenant/utils/tenantRouteContext'

const productRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/products',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'products',
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
        component: () => import('../pages/ProductsPage.vue'),
      },
      {
        path: 'brands',
        name: 'app-product-brands-page',
        component: () => import('../pages/ProductBrandsPage.vue'),
      },
      {
        path: 'categories',
        name: 'app-product-categories-page',
        component: () => import('../pages/ProductCategoriesPage.vue'),
      },
      {
        path: ':id',
        name: 'app-product-details-page',
        component: () => import('../pages/ProductDetailsPage.vue'),
      },
    ],
  },
]

export default productRoutes
