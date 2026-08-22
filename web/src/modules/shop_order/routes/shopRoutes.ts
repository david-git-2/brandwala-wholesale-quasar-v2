import type { RouteRecordRaw } from 'vue-router';
import { createShopAccessGuard } from 'src/modules/auth/guards/createShopAccessGuard';

const shopRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/shop/orders',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-orders-page',
        component: () => import('src/modules/shop_order/pages/CustomerOrdersPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_order_mgmt' }),
      },
      {
        path: 'wallet',
        name: 'shop-merchant-wallet-page',
        component: () => import('src/modules/shop_order/pages/MerchantWalletPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_order_mgmt' }),
      },
      {
        path: ':id',
        name: 'shop-order-detail-page',
        component: () => import('src/modules/shop_order/pages/CustomerOrderDetailPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_order_mgmt' }),
      },
    ],
  },

  {
    path: '/:tenantSlug?/shop/browse',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-catalog-entry-page',
        component: () => import('src/modules/shop_order/pages/CatalogEntryPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_storefront' }),
      },
      {
        path: ':shopSlug/product/:productId',
        name: 'shop-storefront-product-detail-page',
        component: () => import('src/modules/shop_order/pages/StorefrontProductDetailPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_storefront' }),
      },
      {
        path: ':shopSlug',
        name: 'shop-storefront-browse-page',
        component: () => import('src/modules/shop_order/pages/StorefrontPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_storefront' }),
      },
    ],
  },

  {
    path: '/:tenantSlug?/shop/cart',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-cart-page',
        component: () => import('src/modules/shop_order/pages/ShopCartPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_cart' }),
      },
    ],
  },

  {
    path: '/:tenantSlug?/shop/checkout',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-checkout-page',
        component: () => import('src/modules/shop_order/pages/ShopCheckoutPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_cart' }),
      },
    ],
  },

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
