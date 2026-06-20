import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftSettingsRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/settings',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'thrift_settings',
    }),
    children: [
      {
        path: '',
        name: 'thrift-settings-page',
        component: () => import('../pages/ThriftSettingsPage.vue'),
        meta: {
          title: 'Thrift Settings',
          headerTitle: 'Thrift Settings',
        },
      },
    ],
  },
];

export default thriftSettingsRoutes;
