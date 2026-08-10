import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  requireTenantContext: true,
};

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/couriers',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_sales',
    }),
    children: [
      {
        path: '',
        name: 'thrift-couriers-page',
        component: () => import('../courier/pages/ThriftCourierPage.vue'),
        meta: {
          title: 'Courier Providers',
          headerTitle: 'Courier Providers',
        },
      },
    ],
  },
];

export default routes;
