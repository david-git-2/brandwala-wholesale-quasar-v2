import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const commerceAccountingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop/accounting',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-commerce-accounting',
        component: () => import('../pages/CommerceAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin'],
          requiredModule: 'commerce_accounting',
        }),
      },
    ],
  },
]

export default commerceAccountingRoutes
