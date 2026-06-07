import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const marketRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/markets',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        name: 'platform-markets',
        component: () => import('../pages/MarketsPage.vue'),
      },
    ],
  },
]

export default marketRoutes
