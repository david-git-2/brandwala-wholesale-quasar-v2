import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  });

const peopleRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/people',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: guard('people'),
    children: [
      {
        path: '',
        name: 'app-people',
        component: () => import('../pages/PeoplePage.vue'),
        meta: {
          title: 'People',
          headerTitle: 'People',
        },
      },
    ],
  },
];

export default peopleRoutes;
