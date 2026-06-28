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
    path: '/:tenantSlug?/app/thrift/shelves',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_shelf',
    }),
    children: [
      {
        path: '',
        name: 'thrift-shelves-page',
        component: () => import('../shelf/pages/ThriftShelfPage.vue'),
        meta: {
          title: 'Thrift Shelves',
          headerTitle: 'Thrift Shelves',
        },
      },
    ],
  },
];

export default routes;
