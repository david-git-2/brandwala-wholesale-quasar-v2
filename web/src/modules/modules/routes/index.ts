import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const tenantRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/modules',
    component: () => import('layouts/SuperAdminLayout.vue'),
    name: 'platform-modules',
    beforeEnter: createAccessGuard(['superadmin'], 'superadmin-login-page'),
    children: [
      {
        path: '',
        component: () => import('../pages/ModulesPage.vue'),
      },
    ],
  },
]

export default tenantRoutes
