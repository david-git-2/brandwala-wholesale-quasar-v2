import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { createShopAccessGuard } from 'src/modules/auth/guards/createShopAccessGuard';

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
  {
    path: '/:tenantSlug?/shop/notifications',
    component: () => import('layouts/ShopLayout.vue'),
    beforeEnter: createShopAccessGuard({ requiredModule: 'shop_order_mgmt' }),
    children: [
      {
        path: '',
        name: 'shop-notifications-inbox',
        component: () => import('../pages/NotificationInboxPage.vue'),
        meta: {
          title: 'Notifications',
          headerTitle: 'Notifications',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/settings/notifications',
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
        name: 'notifications-preferences',
        component: () => import('../pages/NotificationPreferencesPage.vue'),
        meta: {
          title: 'Notification settings',
          headerTitle: 'Notification settings',
        },
      },
    ],
  },
];

export default notificationRoutes;
