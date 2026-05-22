import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const commerceShopRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin'],
      requireTenantContext: true,
      requiredModule: 'commerce_shop',
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
        redirect: { name: 'app-commerce-shop-manage-page' },
      },
      {
        path: 'manage-store',
        name: 'app-commerce-shop-manage-page',
        component: () => import('src/modules/store/pages/AdminManageStorePage.vue'),
      },
      {
        path: 'manage-access',
        name: 'app-commerce-shop-access-page',
        component: () => import('src/modules/store/pages/AdminManageAccessPage.vue'),
      },
      {
        path: 'store-products',
        name: 'app-commerce-shop-products-page',
        component: () => import('src/modules/store/pages/AdminStoreProductsPage.vue'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/shop/commerce-shop',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-commerce-shop-page',
        component: () => import('src/modules/store/pages/CustomerStorePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'commerce_shop',
        }),
      },
    ],
  },
]

export default commerceShopRoutes
