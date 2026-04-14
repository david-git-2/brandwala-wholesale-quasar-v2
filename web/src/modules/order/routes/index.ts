import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext'

const orderRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/shop/orders',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-order-page',
        component: () => import('../pages/CustomerOrderPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'order_management',
        }),
      },
      {
        path: ':id',
        name: 'shop-order-details-page',
        component: () => import('../pages/CustomerOrderDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'order_management',
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/orders',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-order-page',
        component: () => import('../pages/AdminOrderPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'order_management',
        }),
      },
      {
        path: ':id',
        name: 'app-order-details-page',
        component: () => import('../pages/AdminOrderDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'order_management',
        }),
      },
    ],
  },
]

export default orderRoutes
