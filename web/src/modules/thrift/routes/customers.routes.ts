import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  requireTenantContext: true,
};

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/customers',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_customers',
    }),
    children: [
      {
        path: '',
        name: 'thrift-customers-page',
        component: () => import('../customers/pages/ThriftCustomersPage.vue'),
        meta: {
          title: 'Thrift Customers',
          headerTitle: 'Customers',
        },
      },
    ],
  },
];

export default routes;
