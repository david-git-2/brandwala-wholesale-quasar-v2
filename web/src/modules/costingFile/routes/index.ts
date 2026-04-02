import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext'

const resolveAppCostingLanding = () => {
  const authStore = useAuthStore()

  if (authStore.matchedRole === 'staff') {
    return { name: 'staff-costing-file-page' }
  }

  return { name: 'admin-costing-file-page' }
}

const costingFileRoutes: RouteRecordRaw[] = [
  {
    path: '/app/costing',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'costing_file',
    }),
    children: [
      {
        path: '',
        name: 'costing-file-entry',
        redirect: resolveAppCostingLanding,
      },
      {
        path: 'admin',
        name: 'admin-costing-file-page',
        component: () => import('../pages/AdminCostingFilePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'admin/:id',
        name: 'admin-costing-file-details-page',
        component: () => import('../pages/AdminCostingFileDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
      {
        path: 'staff',
        name: 'staff-costing-file-page',
        component: () => import('../pages/StaffCostingFilePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['staff'],
          requireTenantContext: true,
          requiredModule: 'costing_file',
        }),
      },
    ],
  },
  {
    path: '/shop/:tenantSlug?/costing',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'customer-costing-file-page',
        component: () => import('../pages/CustomerCostingFilePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: [
            'customer_admin',
            'customer_negotiator',
            'customer_staff',
          ],
          requiredModule: 'shop_costing_file',
        }),
      },
      {
        path: ':id',
        name: 'customer-costing-file-details-page',
        component: () => import('../pages/CustomerCostingFileDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: [
            'customer_admin',
            'customer_negotiator',
            'customer_staff',
          ],
          requiredModule: 'shop_costing_file',
        }),
      },
    ],
  },
]

export default costingFileRoutes
