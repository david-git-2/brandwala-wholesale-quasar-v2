import type { RouteRecordRaw } from 'vue-router';

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { createShopAccessGuard } from 'src/modules/auth/guards/createShopAccessGuard';
import { NOTIFICATIONS_ENABLED } from '../notificationsFeature';

const notificationsDisabledRedirect: RouteRecordRaw['beforeEnter'] = (to) => {
  if (NOTIFICATIONS_ENABLED) {
    return true;
  }
  const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : undefined;
  if (to.path.includes('/shop/')) {
    return { name: 'customer-dashboard', params: { tenantSlug } };
  }
  return { name: 'admin-dashboard', params: { tenantSlug } };
};

const notificationRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/notifications',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: [
      notificationsDisabledRedirect,
      createAccessGuard({
        loginRoute: 'admin-login-page',
        requiredScope: 'app',
        allowedRoles: ['admin', 'staff', 'viewer'],
        requireTenantContext: true,
      }),
    ],
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
    beforeEnter: [notificationsDisabledRedirect, createShopAccessGuard({ requiredModule: 'shop_order_mgmt' })],
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
    beforeEnter: [
      notificationsDisabledRedirect,
      createAccessGuard({
        loginRoute: 'admin-login-page',
        requiredScope: 'app',
        allowedRoles: ['admin', 'staff', 'viewer'],
        requireTenantContext: true,
      }),
    ],
    children: [
      {
        path: '',
        name: 'notifications-preferences',
        component: () => import('../pages/NotificationPreferencesPage.vue'),
        meta: {
          title: 'Browser alerts',
          headerTitle: 'Browser alerts',
        },
      },
    ],
  },
];

export default notificationRoutes;
