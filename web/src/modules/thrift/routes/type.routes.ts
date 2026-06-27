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
    path: '/:tenantSlug?/app/thrift/types',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_type',
    }),
    children: [
      {
        path: '',
        name: 'thrift-types-page',
        component: () => import('../type/pages/ThriftTypePage.vue'),
        meta: {
          title: 'Thrift Types',
          headerTitle: 'Thrift Types',
        },
      },
    ],
  },
];

export default routes;
