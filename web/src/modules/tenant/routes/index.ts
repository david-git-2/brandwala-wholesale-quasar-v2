import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const tenantRoutes: RouteRecordRaw[] = [
  // SUPERADMIN ROUTES
  {
    path: '/platform/tenants',
    component: () => import('layouts/PlatformLayout.vue'),
    name: 'platform-tenants',
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
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
    children: [
      {
        path: '',
        name: 'admin-tenant-list',
        component: () => import('../pages/AdminTenantPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
        }),
      },
      {
        path: ':id',
        name: 'admin-tenant-details',
        component: () => import('../pages/AdminTenantDetailsPage.vue'),
        props: true,
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
          validateAccess: ({ authStore, to }) => {
            const selectedTenantId = authStore.selectedTenant?.id
            const routeTenantId = Number(to.params?.id)

            if (!selectedTenantId) {
              return { name: 'admin-tenant-list' }
            }

            if (!Number.isFinite(routeTenantId) || routeTenantId === selectedTenantId) {
              return true
            }

            return {
              name: 'admin-tenant-details',
              params: {
                id: selectedTenantId,
              },
            }
          },
        }),
      },
    ],
  },
]

export default tenantRoutes
