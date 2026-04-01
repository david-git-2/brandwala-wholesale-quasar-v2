import type { RouteRecordRaw } from 'vue-router';

const authRoutes: RouteRecordRaw[] = [
  {
    path: '/auth',
    component: () => import('src/layouts/AuthLayout.vue'),
    children: [
      {
        path: '',
        redirect: { name: 'login-page' },
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
          allowedRoles: ['admin', 'staff'],
        },
      },
      {
        path: 'platform/login',
        name: 'superadmin-login-page',
        component: () => import('../pages/SuperadminLogin.vue'),
        meta: {
          authScope: 'platform',
          allowedRoles: ['superadmin'],
        },
      },
      {
        path: 'shop/login',
        name: 'customer-login-page',
        component: () => import('../pages/CustomerLogin.vue'),
        meta: {
          authScope: 'shop',
          allowedRoles: ['customer', 'viewer'],
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
