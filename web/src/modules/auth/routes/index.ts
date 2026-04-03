import type { RouteRecordRaw } from 'vue-router'

const authRoutes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('src/layouts/AuthLayout.vue'),
    children: [
      {
        path: '/platform/login',
        name: 'superadmin-login-page',
        component: () => import('../pages/SuperadminLogin.vue'),
        meta: {
          authScope: 'platform',
          requiredScope: 'platform',
        },
      },
      {
        path: '/:tenantSlug?/app/login',
        alias: '/app/login',
        name: 'admin-login-page',
        component: () => import('../pages/AdminLogin.vue'),
        meta: {
          authScope: 'app',
          requiredScope: 'app',
        },
      },
      {
        path: '/:tenantSlug?/shop/login',
        alias: '/shop/login',
        name: 'customer-login-page',
        component: () => import('../pages/CustomerLogin.vue'),
        meta: {
          authScope: 'shop',
          requiredScope: 'shop',
        },
      },
      {
        path: '/auth/callback',
        name: 'auth-callback-page',
        component: () => import('../pages/OAuthCallback.vue'),
      },
    ],
  },
  {
    path: '/auth',
    redirect: '/app/login',
  },
  {
    path: '/auth/platform/login',
    redirect: '/platform/login',
  },
  {
    path: '/auth/app/login',
    redirect: '/app/login',
  },
  {
    path: '/auth/:tenantSlug/app/login',
    redirect: (to) =>
      typeof to.params.tenantSlug === 'string'
        ? `/${to.params.tenantSlug}/app/login`
        : '/app/login',
  },
  {
    path: '/auth/shop/login',
    redirect: '/shop/login',
  },
  {
    path: '/auth/:tenantSlug/shop/login',
    redirect: (to) =>
      typeof to.params.tenantSlug === 'string'
        ? `/${to.params.tenantSlug}/shop/login`
        : '/shop/login',
  },
]

export default authRoutes
