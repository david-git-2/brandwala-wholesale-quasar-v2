import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const marketRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/markets',
    component: () => import('layouts/PlatformLayout.vue'),
    name: 'platform-markets',
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        component: () => import('../pages/MarketsPage.vue'),
      },
    ],
  },
]

export default marketRoutes
