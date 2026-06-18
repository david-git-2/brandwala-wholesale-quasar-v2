import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const inventoryRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/stock',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-tenant-stock-page',
        component: () => import('src/modules/global/pages/TenantStockPage.vue'),
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
