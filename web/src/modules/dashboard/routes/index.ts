import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const dashboardRoutes: RouteRecordRaw[] = [
  {
    path: '/platform',
    component: () => import('layouts/SuperAdminLayout.vue'),
    children: [
      {
        path: 'dashboard',
        name: 'superadmin-dashboard',
        component: () => import('../pages/SuperadminDashboard.vue'),
        beforeEnter: createAccessGuard(['superadmin'], 'superadmin-login-page'),
      },
    ],
  },
  {
    path: '/app',
    component: () => import('layouts/AdminLayout.vue'),
    children: [
      {
        path: 'dashboard',
        name: 'admin-dashboard',
        component: () => import('../pages/AdminDashboard.vue'),
        beforeEnter: createAccessGuard(['admin', 'staff'], 'login-page'),
      },
    ],
  },
  {
    path: '/shop',
    component: () => import('layouts/CustomerLayout.vue'),
    children: [
      {
        path: 'dashboard',
        name: 'customer-dashboard',
        component: () => import('../pages/CustomerDashboard.vue'),
        beforeEnter: createAccessGuard(['customer', 'viewer'], 'customer-login-page'),
      },
    ],
  },
]

export default dashboardRoutes
