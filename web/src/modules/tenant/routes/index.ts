import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const tenantRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/tenants',
    component: () => import('layouts/AdminLayout.vue'),
    name: 'platform-tenants',
    beforeEnter: createAccessGuard(['superadmin'], 'superadmin-login-page'),
    children: [
      {
        path: '',
        component: () => import('../pages/TenantPage.vue'),
      },
    ],
  },
]

export default tenantRoutes
