import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const membershipRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/superadmins',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        name: 'superadmin-management',
        component: () => import('../pages/SuperadminManagementPage.vue'),
      },
    ],
  },
]

export default membershipRoutes
