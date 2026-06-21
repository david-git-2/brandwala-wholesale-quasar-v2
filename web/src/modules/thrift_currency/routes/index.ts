import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftCurrencyRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/currencies',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'thrift_currency',
    }),
    children: [
      {
        path: '',
        name: 'thrift-currencies-page',
        component: () => import('../pages/ThriftCurrencyPage.vue'),
        meta: {
          title: 'Thrift Currencies',
          headerTitle: 'Thrift Currencies',
        },
      },
    ],
  },
];

export default thriftCurrencyRoutes;
