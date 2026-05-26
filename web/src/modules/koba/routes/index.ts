import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const kobaRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/koba',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'koba_retail',
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
        redirect: { name: 'app-koba-retail-page' },
      },
      {
        path: 'retail',
        name: 'app-koba-retail-page',
        component: () => import('src/modules/koba/retail/pages/KobaRetailProductsPage.vue'),
      },
    ],
  },
]

export default kobaRoutes
