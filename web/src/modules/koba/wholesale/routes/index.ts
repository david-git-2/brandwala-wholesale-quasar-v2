import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const kobaWholesaleRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/koba',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'koba_wholesale',
      validateAccess: ({ authStore, to }) => {
        const selectedTenantSlug = authStore.selectedTenant?.slug ?? null
        if (!selectedTenantSlug) {
          return true
        }
        const routeTenantSlug = getTenantSlugFromRoute(to)
        if (routeTenantSlug === selectedTenantSlug) {
          return true
        }
        return getAppRouteLocation(to, selectedTenantSlug)
      },
    }),
    children: [
      {
        path: '',
        redirect: { name: 'app-koba-wholesale-page' },
      },
      {
        path: 'wholesale',
        name: 'app-koba-wholesale-page',
        component: () => import('src/modules/koba/wholesale/pages/KobaWholesaleProductsPage.vue'),
      },
    ],
  },
]

export default kobaWholesaleRoutes
