import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { validateAppRouteTenantSlug } from 'src/modules/tenant/utils/tenantRouteContext';

const productRoutes: RouteRecordRaw[] = [
  {
    path: '/app/products',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'products',
      validateAccess: ({ authStore, to }) => validateAppRouteTenantSlug({ authStore, to }),
    }),
    children: [
      {
        path: '',
        name: 'app-products-overview',
        component: () => import('../pages/ProductsOverviewPage.vue'),
      },
      {
        path: 'list',
        component: () => import('../pages/ProductsPage.vue'),
      },
      {
        path: 'overview',
        redirect: (to) => {
          const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
          return tenantSlug ? `/${tenantSlug}/app/products` : '/app/products';
        },
      },
      {
        path: 'brands',
        name: 'app-product-brands-page',
        component: () => import('../pages/ProductBrandsPage.vue'),
      },
      {
        path: 'categories',
        name: 'app-product-categories-page',
        component: () => import('../pages/ProductCategoriesPage.vue'),
      },
      {
        path: ':id',
        name: 'app-product-details-page',
        component: () => import('../pages/ProductDetailsPage.vue'),
      },
    ],
  },
];

export default productRoutes;
