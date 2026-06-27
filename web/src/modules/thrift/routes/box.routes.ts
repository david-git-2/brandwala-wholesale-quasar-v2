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
    path: '/:tenantSlug?/app/thrift/boxes',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_box',
    }),
    children: [
      {
        path: '',
        name: 'thrift-boxes-page',
        component: () => import('../box/pages/ThriftBoxPage.vue'),
        meta: {
          title: 'Thrift Boxes',
          headerTitle: 'Thrift Boxes',
        },
      },
    ],
  },
];

export default routes;
