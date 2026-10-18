import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const helpHomeComponent = () => import('../pages/HelpHomePage.vue');

const helpRoutes: RouteRecordRaw[] = [
  {
    path: '/help',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'help-home',
        component: helpHomeComponent,
        meta: {
          title: 'Help',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/help',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-help-center',
        component: helpHomeComponent,
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff', 'viewer'],
          requireTenantContext: true,
        }),
        meta: {
          title: 'Help',
        },
      },
    ],
  },
];

export default helpRoutes;
