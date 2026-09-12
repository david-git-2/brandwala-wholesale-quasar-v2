import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const notificationRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/notifications',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff', 'viewer'],
      requireTenantContext: true,
    }),
    children: [
      {
        path: '',
        name: 'notifications-inbox',
        component: () => import('../pages/NotificationInboxPage.vue'),
        meta: {
          title: 'Notifications',
          headerTitle: 'Notifications',
        },
      },
    ],
  },
];

export default notificationRoutes;
