import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext'

const commerceShopRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-commerce-shop-page',
        component: () => import('../pages/CommerceShopPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'commerce_shop',
        }),
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
        component: () => import('../pages/CommerceShopPage.vue'),
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
