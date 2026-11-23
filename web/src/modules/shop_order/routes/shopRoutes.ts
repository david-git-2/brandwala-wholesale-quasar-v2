import type { RouteRecordRaw } from 'vue-router';
import { createShopAccessGuard } from 'src/modules/auth/guards/createShopAccessGuard';

const SHOP_TYPE = ':shopType(catalog|stock|dropship)';

const browseChildren: RouteRecordRaw[] = [
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
];

const shopRoutes: RouteRecordRaw[] = [
  {
    path: `/shop/:tenantSlug/${SHOP_TYPE}/orders`,
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
        redirect: { name: 'shop-orders-page' },
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
    path: `/shop/:tenantSlug/${SHOP_TYPE}/browse`,
    component: () => import('layouts/ShopLayout.vue'),
    children: browseChildren,
  },

  {
    path: `/shop/:tenantSlug/${SHOP_TYPE}/cart`,
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-cart-page',
        component: () => import('src/modules/shop_order/pages/ShopCartEntryPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_cart' }),
      },
    ],
  },

  {
    path: `/shop/:tenantSlug/dropship/review`,
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-dropship-review-page',
        component: () => import('src/modules/shop_order/pages/ShopDropshipReviewPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_cart' }),
      },
    ],
  },

  {
    path: `/shop/:tenantSlug/dropship/delivery`,
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-dropship-delivery-page',
        component: () => import('src/modules/shop_order/pages/ShopDropshipDeliveryPage.vue'),
        beforeEnter: createShopAccessGuard({ requiredModule: 'shop_cart' }),
      },
    ],
  },

  {
    path: `/shop/:tenantSlug/dropship/checkout`,
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
    path: '/shop/:tenantSlug/browse/:shopSlug',
    redirect: (to) => {
      const tenantSlug = String(to.params.tenantSlug ?? '');
      const shopSlug = String(to.params.shopSlug ?? '');
      return `/shop/${tenantSlug}/catalog/browse/${shopSlug}`;
    },
  },

  {
    path: '/shop/:tenantSlug/browse',
    redirect: (to) => {
      const tenantSlug = String(to.params.tenantSlug ?? '');
      return `/shop/${tenantSlug}/catalog/browse`;
    },
  },

  {
    path: '/shop/:tenantSlug/commerce/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = String(to.params.tenantSlug ?? '');
      const subPath = to.params.catchAll
        ? `/${Array.isArray(to.params.catchAll) ? to.params.catchAll.join('/') : to.params.catchAll}`
        : '';
      return `/shop/${tenantSlug}/catalog${subPath}`;
    },
  },
  {
    path: '/shop/:tenantSlug/commerce-shop/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = String(to.params.tenantSlug ?? '');
      const subPath = to.params.catchAll
        ? `/${Array.isArray(to.params.catchAll) ? to.params.catchAll.join('/') : to.params.catchAll}`
        : '';
      return `/shop/${tenantSlug}/catalog${subPath}`;
    },
  },
  {
    path: '/shop/:tenantSlug/stores/:catchAll(.*)*',
    redirect: () => '/app/shop',
  },
];

export default shopRoutes;