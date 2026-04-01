import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const tenantRoutes: RouteRecordRaw[] = [
  // SUPERADMIN ROUTES
  {
    path: '/platform/tenants',
    component: () => import('layouts/PlatformLayout.vue'),
    name: 'platform-tenants',
    beforeEnter: createAccessGuard({
      loginRouteName: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: '',
        name: 'tenant-list',
        component: () => import('../pages/TenantPage.vue'),
      },
      {
        path: ':id',
        name: 'tenant-details',
        component: () => import('../pages/TenantDetailsPage.vue'),
        props: true,
      },
    ],
  },

  // ADMIN ROUTES
  {
    path: '/app/tenants',
    component: () => import('layouts/AppLayout.vue'),
    name: 'admin-tenants',
    beforeEnter: createAccessGuard({
      loginRouteName: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin'],
    }),
    children: [
      {
        path: '',
        name: 'admin-tenant-list',
        component: () => import('../pages/AdminTenantPage.vue'),
      },
      {
        path: ':id',
        name: 'admin-tenant-details',
        component: () => import('../pages/AdminTenantDetailsPage.vue'),
        props: true,
      },
    ],
  },
]

export default tenantRoutes
