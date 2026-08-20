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
          scope: 'app',
          moduleKey: 'customer',
          requiredAction: 'view',
          breadcrumbs: [
            { label: 'Dashboard', to: '/app/dashboard' },
            { label: 'Customers' },
          ],
        }),
      },
      {
        path: 'create',
        name: 'app-customers-create',
        component: () => import('../pages/CreateCustomerPage.vue'),
        beforeEnter: createAccessGuard({
          scope: 'app',
          moduleKey: 'customer',
          requiredAction: 'create',
          breadcrumbs: [
            { label: 'Dashboard', to: '/app/dashboard' },
            { label: 'Customers', to: '/app/customers' },
            { label: 'Create Customer' },
          ],
        }),
      },
    ],
  },
];

export default customerRoutes;
