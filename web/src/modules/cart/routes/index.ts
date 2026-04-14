import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext'

const cartRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/shop/cart',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-cart-page',
        component: () => import('../pages/CustomerCartPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'cart',
        }),
      },
    ],
  },
]

export default cartRoutes
