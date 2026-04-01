import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const featureCatalogRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/modules',
    component: () => import('layouts/PlatformLayout.vue'),
    name: 'platform-modules',
    beforeEnter: createAccessGuard({
      loginRouteName: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        component: () => import('../pages/ModulesPage.vue'),
      },
    ],
  },
]

export default featureCatalogRoutes
