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
          allowedRoles: ['admin', 'staff', 'viewer'],
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
      {
        path: ':id/customer-groups',
        name: 'admin-tenant-customer-groups',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          return tenantSlug ? `/${tenantSlug}/app/access-control/customer-groups` : '/app/access-control/customer-groups'
        }
      },
      {
        path: ':id/staff',
        name: 'admin-tenant-staff',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          return tenantSlug ? `/${tenantSlug}/app/access-control/team` : '/app/access-control/team'
        }
      },
      {
        path: ':id/investors',
        name: 'admin-tenant-investors',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          return tenantSlug ? `/${tenantSlug}/app/access-control/investors` : '/app/access-control/investors'
        }
      },
      {
        path: ':id/modules',
        name: 'admin-tenant-modules',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          return tenantSlug ? `/${tenantSlug}/app/access-control/modules` : '/app/access-control/modules'
        }
      },
      {
        path: ':id/preferences',
        name: 'admin-tenant-preferences',
        component: () => import('../pages/AdminTenantPreferencesPage.vue'),
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
                name: 'admin-tenant-preferences',
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
  // ROLE & SETTINGS ROUTES
  {
    path: '/:tenantSlug?/app/settings',
    component: () => import('layouts/AppLayout.vue'),
    name: 'admin-settings',
    children: [
      {
        path: 'roles',
        name: 'admin-settings-roles',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          return tenantSlug ? `/${tenantSlug}/app/access-control/roles` : '/app/access-control/roles'
        }
      },
      {
        path: 'roles/:id/grants',
        name: 'admin-settings-role-grants',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          const id = String(to.params.id)
          return tenantSlug ? `/${tenantSlug}/app/access-control/roles/${id}/grants` : `/app/access-control/roles/${id}/grants`
        }
      },
    ],
  },
  // SHOP ROLES ROUTE
  {
    path: '/:tenantSlug?/app/shop',
    component: () => import('layouts/AppLayout.vue'),
    name: 'admin-shop-settings',
    children: [
      {
        path: 'roles',
        name: 'admin-shop-roles',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          return tenantSlug ? `/${tenantSlug}/app/access-control/roles` : '/app/access-control/roles'
        }
      },
      {
        path: 'roles/:id/grants',
        name: 'admin-shop-role-grants',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to)
          const id = String(to.params.id)
          return tenantSlug ? `/${tenantSlug}/app/access-control/roles/${id}/grants` : `/app/access-control/roles/${id}/grants`
        }
      },
    ],
  },
]

export default tenantRoutes
