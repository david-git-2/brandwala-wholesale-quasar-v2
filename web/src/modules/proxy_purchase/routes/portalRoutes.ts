import type { RouteRecordRaw } from 'vue-router';

import { createProxyAccessGuard } from 'src/modules/proxy_purchase/guards/createProxyAccessGuard';

const proxyPortalGuard = createProxyAccessGuard();

const proxyPortalRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug/proxy/login',
    component: () => import('src/layouts/AuthLayout.vue'),
    children: [
      {
        path: '',
        name: 'proxy-login-page',
        component: () => import('../pages/portal/ProxyLoginPage.vue'),
        meta: {
          authScope: 'proxy',
          requiredScope: 'proxy',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug/proxy/select-group',
    component: () => import('src/layouts/AuthLayout.vue'),
    children: [
      {
        path: '',
        name: 'proxy-select-group-page',
        component: () => import('../pages/portal/ProxySelectGroupPage.vue'),
        meta: {
          authScope: 'proxy',
          requiredScope: 'proxy',
        },
      },
    ],
  },
  {
    path: '/:tenantSlug/proxy',
    component: () => import('src/layouts/ProxyLayout.vue'),
    beforeEnter: proxyPortalGuard,
    children: [
      {
        path: '',
        name: 'proxy-dashboard-page',
        component: () => import('../pages/portal/ProxyDashboardPage.vue'),
        meta: { authScope: 'proxy' },
      },
    ],
  },
];

export default proxyPortalRoutes;