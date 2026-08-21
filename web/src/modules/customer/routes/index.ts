import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const customerRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/customers',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-customers',
        component: () => import('../pages/CustomerHubPage.vue'),
        beforeEnter: createAccessGuard({
          requiredScope: 'app',
          requiredModule: 'customer',
          loginRoute: (to) => ({ name: 'login', query: { redirect: to.fullPath } }),
        }),
      },
      {
        path: 'create',
        name: 'app-customers-create',
        component: () => import('../pages/CreateCustomerPage.vue'),
        beforeEnter: createAccessGuard({
          requiredScope: 'app',
          requiredModule: 'customer',
          requiredModuleAction: 'create',
          loginRoute: (to) => ({ name: 'login', query: { redirect: to.fullPath } }),
        }),
      },
    ],
  },
];

export default customerRoutes;
