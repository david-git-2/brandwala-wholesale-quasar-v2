import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/workspace/submodules/auth/guards/accessGuard';
import { validateAppRouteTenantSlug } from 'src/modules/tenant/utils/tenantRouteContext';

const productBasedCostingRoutes: RouteRecordRaw[] = [
  {
    path: '/app/product-based-costing',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'product_based_costing',
      validateAccess: ({ authStore, to }) => validateAppRouteTenantSlug({ authStore, to }),
    }),
    children: [
      {
        path: '',
        name: 'product-based-costing-page',
        component: () => import('../pages/ProductBasedCostingPage.vue'),
        meta: { hasPageToolbar: true },
      },
      {
        path: ':id/add-product-cart',
        name: 'product-based-costing-add-product-cart-page',
        component: () => import('../pages/AddProductCartPage.vue'),
        props: true,
        meta: { hasPageToolbar: true },
      },
      {
        path: ':id/delivery-paper/:paperId',
        name: 'product-based-costing-delivery-paper-page',
        component: () =>
          import('src/modules/procurement_stock/pages/DeliveryPaperDetailPage.vue'),
        props: (route) => ({
          documentType: 'pbc_costing_file' as const,
          documentId: Number(route.params.id),
        }),
        meta: { hasPageToolbar: true },
      },
      {
        path: ':id',
        name: 'product-based-costing-file-details-page',
        component: () => import('../pages/ProductBasedCostingFileDetailsPage.vue'),
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
    path: '/app/product-based-costing/:id/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'product_based_costing',
      validateAccess: ({ authStore, to }) => validateAppRouteTenantSlug({ authStore, to }),
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
