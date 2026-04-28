import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const inventoryRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/inventory',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-inventory-page',
        component: () => import('../pages/AdminInventoryPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'inventory',
        }),
      },
    ],
  },
]

export default inventoryRoutes
