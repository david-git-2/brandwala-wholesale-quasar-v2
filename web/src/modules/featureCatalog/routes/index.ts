import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const featureCatalogRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/modules',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        name: 'platform-modules',
        component: () => import('../pages/ModulesPage.vue'),
      },
    ],
  },
]

export default featureCatalogRoutes
