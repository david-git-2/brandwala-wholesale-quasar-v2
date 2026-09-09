import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

const productBasedCostingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/product-based-costing',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'product_based_costing',
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
        path: '',
        name: 'product-based-costing-page',
        component: () => import('../pages/ProductBasedCostingPage.vue'),
        meta: { hasPageToolbar: true },
      },
      {
        path: ':id',
        name: 'product-based-costing-file-details-page',
        component: () => import('../pages/ProductBasedCostingFileDetailsV2Page.vue'),
        props: true,
        meta: { hasPageToolbar: true },
      },
      {
        path: ':id/v2',
        redirect: (to) => ({
          name: 'product-based-costing-file-details-page',
          params: {
            tenantSlug: to.params.tenantSlug,
            id: to.params.id,
          },
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/product-based-costing/:id/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'product_based_costing',
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
        path: '',
        name: 'product-based-costing-file-preview-page',
        component: () => import('../pages/ProductBasedCostingSharedPreviewPage.vue'),
        props: true,
      },
    ],
  },
];

export default productBasedCostingRoutes;
