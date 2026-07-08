import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

const documentationRoutes: RouteRecordRaw[] = [
  // App Scope (Tenant Workspace) - Standalone Layout
  {
    path: '/:tenantSlug?/app/documentation',
    component: () => import('../layouts/DocumentationLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff', 'viewer'],
      requireTenantContext: true,
      validateAccess: ({ authStore, to }) => {
        const selectedTenantSlug = authStore.selectedTenant?.slug ?? null;

        if (!selectedTenantSlug) {
          return true;
        }

        const routeTenantSlug = getTenantSlugFromRoute(to);

        if (routeTenantSlug === selectedTenantSlug) {
          return true;
        }

        return getAppRouteLocation(to, selectedTenantSlug);
      },
    }),
    children: [
      {
        path: ':docKey?',
        name: 'app-documentation-page',
        component: () => import('../pages/DocumentationPage.vue'),
      },
    ],
  },

  // Platform Scope (Super Admin Dashboard) - Standalone Layout
  {
    path: '/platform/documentation',
    component: () => import('../layouts/DocumentationLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'superadmin-login-page',
      requiredScope: 'platform',
      allowedRoles: ['superadmin'],
    }),
    children: [
      {
        path: ':docKey?',
        name: 'platform-documentation-page',
        component: () => import('../pages/DocumentationPage.vue'),
      },
    ],
  },
];

export default documentationRoutes;
