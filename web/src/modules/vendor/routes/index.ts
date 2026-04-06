import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const vendorRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/vendors',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin'],
      requireTenantContext: true,
      requiredModule: 'vendor',
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
        name: 'app-vendors-page',
        component: () => import('../pages/VendorsPage.vue'),
      },
    ],
  },
  {
    path: '/platform/vendors',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        name: 'platform-vendors-page',
        component: () => import('../pages/VendorsPage.vue'),
      },
    ],
  },
]

export default vendorRoutes
