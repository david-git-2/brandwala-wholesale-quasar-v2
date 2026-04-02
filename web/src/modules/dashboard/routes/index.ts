import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const dashboardRoutes: RouteRecordRaw[] = [
  {
    path: '/platform',
    component: () => import('layouts/PlatformLayout.vue'),
    children: [
      {
        path: 'dashboard',
        name: 'superadmin-dashboard',
        component: () => import('../pages/SuperadminDashboard.vue'),
        beforeEnter: createAccessGuard({
          loginRouteName: 'superadmin-login-page',
          requiredScope: 'platform',
          allowedRoles: ['superadmin'],
        }),
      },
    ],
  },
  {
    path: '/app',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: 'dashboard',
        name: 'admin-dashboard',
        component: () => import('../pages/AdminDashboard.vue'),
        beforeEnter: createAccessGuard({
          loginRouteName: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
        }),
      },
    ],
  },
  {
    path: '/shop',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: 'dashboard',
        name: 'customer-dashboard',
        component: () => import('../pages/CustomerDashboard.vue'),
        beforeEnter: createAccessGuard({
          loginRouteName: 'customer-login-page',
          requiredScope: 'shop',
          allowedRoles: [
            'customer_admin',
            'customer_negotiator',
            'customer_staff',
          ],
        }),
      },
    ],
  },
]

export default dashboardRoutes
