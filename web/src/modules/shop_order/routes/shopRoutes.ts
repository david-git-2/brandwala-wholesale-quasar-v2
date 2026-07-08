import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { getShopLoginRouteLocation } from 'src/modules/tenant/utils/tenantRouteContext';

const shopRoutes: RouteRecordRaw[] = [
  // shop_order_mgmt — Customer Orders (shop scope)
  {
    path: '/:tenantSlug?/shop/orders',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-orders-page',
        component: () => import('src/modules/shop_order/pages/CustomerOrdersPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'shop_order_mgmt',
        }),
      },
      {
        path: ':id',
        name: 'shop-order-detail-page',
        component: () => import('src/modules/shop_order/pages/CustomerOrderDetailPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'shop_order_mgmt',
        }),
      },
    ],
  },

  // shop_storefront — Customer Storefront (P5)
  {
    path: '/:tenantSlug?/shop/browse/:shopSlug',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-storefront-browse-page',
        component: () => import('src/modules/shop_order/pages/StorefrontPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'shop_storefront',
        }),
      },
    ],
  },

  // shop_cart — Customer Cart (P6)
  {
    path: '/:tenantSlug?/shop/cart',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-cart-page',
        component: () => import('src/modules/shop_order/pages/ShopCartPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'shop_cart',
        }),
      },
    ],
  },

  // shop_cart — Customer Checkout (P6)
  {
    path: '/:tenantSlug?/shop/checkout',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-checkout-page',
        component: () => import('src/modules/shop_order/pages/ShopCheckoutPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'shop_cart',
        }),
      },
    ],
  },

  // Legacy redirects (Phase 9)
  {
    path: '/:tenantSlug?/shop/commerce/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      const subPath = to.params.catchAll
        ? `/${Array.isArray(to.params.catchAll) ? to.params.catchAll.join('/') : to.params.catchAll}`
        : '';
      return `${tenantSlug}/shop${subPath}`;
    },
  },
  {
    path: '/:tenantSlug?/shop/commerce-shop/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      const subPath = to.params.catchAll
        ? `/${Array.isArray(to.params.catchAll) ? to.params.catchAll.join('/') : to.params.catchAll}`
        : '';
      return `${tenantSlug}/shop${subPath}`;
    },
  },
  {
    path: '/:tenantSlug?/shop/stores/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      return `${tenantSlug}/app/shop/shops`;
    },
  },
];

export default shopRoutes;
