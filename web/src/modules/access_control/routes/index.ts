import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const accessControlRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/access-control',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        redirect: (to) => {
          const tenantSlug = Array.isArray(to.params.tenantSlug)
            ? to.params.tenantSlug[0]
            : to.params.tenantSlug
          return tenantSlug ? `/${tenantSlug}/app/access-control/modules` : '/app/access-control/modules'
        },
      },
      {
        path: 'roles/:id/grants',
        name: 'admin-access-control-role-grants',
        component: () => import('../pages/AccessControlRoleGrantsPage.vue'),
        props: (route) => ({ id: Number(route.params.id) }),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
        }),
      },
      {
        path: ':tab',
        name: 'admin-access-control',
        component: () => import('../pages/AccessControlPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin'],
          requireTenantContext: true,
        }),
      },
    ],
  },
]

export default accessControlRoutes
