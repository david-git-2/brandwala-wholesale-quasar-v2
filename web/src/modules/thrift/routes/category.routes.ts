import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  allowedRoles: ['admin', 'staff'] as const,
  requireTenantContext: true,
};

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/categories',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_category',
    }),
    children: [
      {
        path: '',
        name: 'thrift-categories-page',
        component: () => import('../category/pages/ThriftCategoryPage.vue'),
        meta: {
          title: 'Thrift Categories',
          headerTitle: 'Thrift Categories',
        },
      },
    ],
  },
];

export default routes;
