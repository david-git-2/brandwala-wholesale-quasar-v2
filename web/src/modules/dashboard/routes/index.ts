import type { RouteRecordRaw } from 'vue-router'

import { useAuthStore } from 'src/modules/auth/stores/authStore'

type DashboardRole = 'superadmin' | 'admin' | 'staff' | 'customer' | 'viewer'

const createAccessGuard = (allowedRoles: DashboardRole[], loginRouteName: string) => {
  return () => {
    const authStore = useAuthStore()
    const memberRole = authStore.member?.role

    if (!authStore.isAuthenticated || !memberRole || !allowedRoles.includes(memberRole)) {
      return { name: loginRouteName }
    }

    return true
  }
}

const dashboardRoutes: RouteRecordRaw[] = [
  {
    path: '/platform',
    component: () => import('layouts/MainLayout.vue'),
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
    component: () => import('layouts/MainLayout.vue'),
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
    component: () => import('layouts/MainLayout.vue'),
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
