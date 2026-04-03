import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { getAppRouteLocation, getTenantSlugFromRoute } from 'src/modules/tenant/utils/tenantRouteContext'

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
    path: '/:tenantSlug?/app/tenants',
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
          validateAccess: ({ authStore, to }) => {
            if (!authStore.selectedTenant) {
              return true
            }

            const routeTenantSlug = getTenantSlugFromRoute(to)
            const selectedTenantSlug = authStore.selectedTenant.slug

            if (routeTenantSlug === selectedTenantSlug) {
              return true
            }

            return getAppRouteLocation(to, selectedTenantSlug)
          },
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
            const routeTenantSlug = getTenantSlugFromRoute(to)
            const selectedTenantSlug = authStore.selectedTenant?.slug ?? null

            if (!selectedTenantId) {
              return { name: 'admin-tenant-list' }
            }

            if (
              Number.isFinite(routeTenantId) &&
              routeTenantId === selectedTenantId &&
              routeTenantSlug === selectedTenantSlug
            ) {
              return true
            }

            return getAppRouteLocation(
              {
                ...to,
                name: 'admin-tenant-details',
                params: {
                  ...(to.params ?? {}),
                  id: selectedTenantId,
                },
              },
              selectedTenantSlug,
            )
          },
        }),
      },
    ],
  },
]

export default tenantRoutes
