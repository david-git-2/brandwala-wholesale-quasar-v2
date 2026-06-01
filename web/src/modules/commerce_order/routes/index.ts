import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const commerceOrderRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop/orders',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-commerce-orders',
        component: () => import('../pages/CommerceOrdersPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'commerce_order',
        }),
      },
    ],
  },
]

export default commerceOrderRoutes
