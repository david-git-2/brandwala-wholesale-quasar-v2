import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/workspace/submodules/auth/guards/accessGuard';

const proxyPurchaseGuard = createAccessGuard({
  loginRoute: 'admin-login-page',
  requiredScope: 'app',
  requireTenantContext: true,
  requiredModule: 'proxy_purchase',
});

const proxyPurchaseRoutes: RouteRecordRaw[] = [
  {
    path: '/app/proxy-purchase',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: proxyPurchaseGuard,
    children: [
      {
        path: '',
        name: 'proxy-purchase-home-page',
        component: () => import('../pages/ProxyPurchaseHomePage.vue'),
        meta: {
          title: 'Proxy Purchase',
          headerTitle: 'Proxy Purchase',
        },
      },
      {
        path: 'config',
        name: 'proxy-purchase-config-page',
        component: () => import('../pages/ProxyPurchaseConfigPage.vue'),
        meta: {
          title: 'Proxy Purchase Settings',
          headerTitle: 'Proxy Purchase Settings',
        },
      },
    ],
  },
];

export default proxyPurchaseRoutes;