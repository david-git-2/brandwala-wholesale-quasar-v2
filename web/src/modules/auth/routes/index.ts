import type { RouteRecordRaw } from 'vue-router';
import { createShopSelectCompanyGuard } from '../guards/createShopAccessGuard';
import { rewriteLegacyShopPath } from 'src/modules/tenant/utils/legacyUrlRedirects';

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
        path: '/app/login',
        name: 'admin-login-page',
        component: () => import('../pages/AdminLogin.vue'),
        meta: {
          authScope: 'app',
          requiredScope: 'app',
        },
      },
      {
        path: '/shop/:tenantSlug/:shopType(catalog|stock|dropship)/login',
        name: 'customer-login-page',
        component: () => import('../pages/CustomerLogin.vue'),
        meta: {
          authScope: 'shop',
          requiredScope: 'shop',
        },
      },
      {
        path: '/shop/:tenantSlug/login',
        component: () => import('../pages/CustomerLogin.vue'),
        meta: {
          authScope: 'shop',
          requiredScope: 'shop',
        },
      },
      {
        path: '/shop/:tenantSlug/:shopType(catalog|stock|dropship)/select-company',
        name: 'shop-select-company-page',
        component: () => import('../pages/ShopCustomerGroupSelectPage.vue'),
        beforeEnter: createShopSelectCompanyGuard(),
        meta: {
          authScope: 'shop',
          requiredScope: 'shop',
        },
      },
      {
        path: '/shop/:tenantSlug/select-company',
        component: () => import('../pages/ShopCustomerGroupSelectPage.vue'),
        beforeEnter: createShopSelectCompanyGuard(),
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
    redirect: '/app/login',
  },
  {
    path: '/auth/shop/login',
    redirect: '/shop/login',
  },
  {
    path: '/auth/:tenantSlug/shop/login',
    redirect: (to) =>
      typeof to.params.tenantSlug === 'string'
        ? `/shop/${to.params.tenantSlug}/login`
        : '/shop/login',
  },
  {
    path: '/:tenantSlug/shop/login',
    redirect: (to) =>
      typeof to.params.tenantSlug === 'string'
        ? {
            path: `/shop/${to.params.tenantSlug}/login`,
            query: {
              ...to.query,
              redirect:
                typeof to.query.redirect === 'string'
                  ? rewriteLegacyShopPath(to.query.redirect)
                  : to.query.redirect,
            },
          }
        : '/shop/login',
  },
];

export default authRoutes;