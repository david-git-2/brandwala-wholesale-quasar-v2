import type { RouteRecordRaw } from 'vue-router';

const authRoutes: RouteRecordRaw[] = [
  {
    path: '/auth',
    component: () => import('src/layouts/AuthLayout.vue'),
    children: [
      {
        path: '',
        redirect: { name: 'admin-login-page' },
      },
      {
        path: 'callback',
        name: 'auth-callback-page',
        component: () => import('../pages/OAuthCallback.vue'),
      },
      {
        path: 'app/login',
        alias: 'app/login',
        name: 'admin-login-page',
        component: () => import('../pages/AdminLogin.vue'),
        meta: {
          authScope: 'app',
          requiredScope: 'app',
        },
      },
      {
        path: 'platform/login',
        name: 'superadmin-login-page',
        component: () => import('../pages/SuperadminLogin.vue'),
        meta: {
          authScope: 'platform',
          requiredScope: 'platform',
        },
      },
      {
        path: 'shop/:tenantSlug?/login',
        name: 'customer-login-page',
        component: () => import('../pages/CustomerLogin.vue'),
        meta: {
          authScope: 'shop',
          requiredScope: 'shop',
        },
      },
      // {
      //   path: 'oauth',
      //   name: 'oauth-page',
      //   component: () => import('src/modules/auth/pages/OAuthPage.vue'),
      // },
      // {
      //   path: 'logout',
      //   name: 'logout-page',
      //   component: () => import('src/modules/auth/pages/LogoutPage.vue'),
      // },
    ],
  },
];

export default authRoutes;
