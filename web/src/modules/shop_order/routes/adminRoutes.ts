import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
    validateAccess: ({ authStore, to }) => {
      const selectedTenantSlug = authStore.selectedTenant?.slug ?? null;

      if (!selectedTenantSlug) {
        return true;
      }

      const routeTenantSlug = getTenantSlugFromRoute(to);

      if (routeTenantSlug === selectedTenantSlug) {
        return true;
      }

      return getAppRouteLocation(to, selectedTenantSlug);
    },
  });

const adminRoutes: RouteRecordRaw[] = [
  // shop_config — Shops
  {
    path: '/:tenantSlug?/app/shop/shops',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-shops-page',
        component: () => import('src/modules/shop_order/pages/ShopSetupHubPage.vue'),
        beforeEnter: guard('shop_config'),
      },
      {
        path: 'list',
        name: 'app-shop-shops-list-page',
        component: () => import('src/modules/shop_order/pages/ShopsPage.vue'),
        beforeEnter: guard('shop_config'),
      },
      {
        path: ':shopId/setup',
        name: 'app-shop-settings-page',
        component: () => import('src/modules/shop_order/pages/ShopSettingsPage.vue'),
        beforeEnter: guard('shop_config'),
      },
      {
        path: ':shopId/access',
        name: 'app-shop-access-matrix-page',
        component: () => import('src/modules/shop_order/pages/ShopAccessMatrixPage.vue'),
        beforeEnter: guard('shop_permissions'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/shop/shops/:shopId/preview',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-preview-page',
        component: () => import('src/modules/shop_order/pages/ShopPreviewPage.vue'),
        beforeEnter: guard('shop_config'),
      },
    ],
  },

  {
    path: '/:tenantSlug?/app/shop/categories',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-categories-page',
        component: () => import('src/modules/shop_order/pages/ShopCategoriesPage.vue'),
        beforeEnter: guard('shop_category'),
      },
    ],
  },

  {
    path: '/:tenantSlug?/app/shop/customer-groups',
    redirect: (to) => ({
      name: 'app-customers',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },
  {
    path: '/:tenantSlug?/app/shop/customer-groups/:pathMatch(.*)*',
    redirect: (to) => ({
      name: 'app-customers',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },

  // shop_pricing — Shop Pricing
  {
    path: '/:tenantSlug?/app/shop/pricing',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-pricing-list-page',
        component: () => import('src/modules/shop_order/pages/ShopPricingListPage.vue'),
        beforeEnter: guard('shop_pricing'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/shop/shops/:shopId/pricing',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-pricing-page',
        component: () => import('src/modules/shop_order/pages/ShopPricingPage.vue'),
        beforeEnter: guard('shop_pricing'),
      },
      {
        path: 'add-listings',
        name: 'app-shop-add-listings-page',
        component: () => import('src/modules/shop_order/pages/AddShopListingsPage.vue'),
        beforeEnter: guard('shop_pricing'),
      },
    ],
  },

  // shop_order_mgmt — Orders (app scope)
  {
    path: '/:tenantSlug?/app/shop/orders',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-orders-page',
        component: () => import('src/modules/shop_order/pages/ShopOrdersPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
      {
        path: ':id',
        name: 'app-shop-order-detail-page',
        component: () => import('src/modules/shop_order/pages/StaffOrderDetailPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
    ],
  },

  {
    path: '/:tenantSlug?/app/shop/shipping',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-shipping-hub-page',
        component: () => import('src/modules/shop_order/pages/ShopShippingHubPage.vue'),
        beforeEnter: guard('shop_shipping'),
      },
    ],
  },

  // shop_fulfillment — retired from nav
  {
    path: '/:tenantSlug?/app/shop/fulfillment',
    redirect: (to) => ({
      name: 'app-shop-orders-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },

  // Dropship process-order pages stay on these URLs; list redirects to Orders.
  {
    path: '/:tenantSlug?/app/shop/dropship',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-dropship-orders-page',
        redirect: (to) => ({
          name: 'app-shop-orders-page',
          params: { tenantSlug: to.params.tenantSlug },
          query: { shopType: 'dropship' },
        }),
      },
      {
        path: 'couriers',
        name: 'app-shop-dropship-couriers-page',
        component: () => import('src/modules/shop_order/pages/DropshipCouriersPage.vue'),
        beforeEnter: guard('shop_shipping'),
      },
      {
        path: 'ledger',
        name: 'app-shop-dropship-ledger-page',
        redirect: (to) => ({
          name: 'app-shop-dropship-finance-hub-page',
          params: { tenantSlug: to.params.tenantSlug },
        }),
      },
      {
        path: 'merchants',
        name: 'app-shop-dropship-merchants-page',
        component: () => import('src/modules/shop_order/pages/DropshipMerchantsPage.vue'),
        beforeEnter: guard('shop_config'),
      },
      {
        path: 'finance-hub',
        name: 'app-shop-dropship-finance-hub-page',
        component: () => import('src/modules/shop_order/pages/DropshipFinanceHubPage.vue'),
        beforeEnter: guard('shop_shipping'),
      },
      {
        path: 'courier-holdings',
        name: 'app-shop-courier-holdings-page',
        redirect: (to) => ({
          name: 'app-shop-dropship-finance-hub-page',
          params: { tenantSlug: to.params.tenantSlug },
          query: { step: 'courier_remittance' },
        }),
      },
      {
        path: 'courier-remittances',
        name: 'app-shop-courier-remittances-list-page',
        redirect: (to) => ({
          name: 'app-shop-dropship-finance-hub-page',
          params: { tenantSlug: to.params.tenantSlug },
          query: { step: 'courier_remittance' },
        }),
      },
      {
        path: 'courier-remittances/new',
        name: 'app-shop-courier-remittance-new-page',
        redirect: (to) => ({
          name: 'app-shop-dropship-finance-hub-page',
          params: { tenantSlug: to.params.tenantSlug },
          query: { step: 'courier_remittance' },
        }),
      },
      {
        path: 'courier-remittances/:id',
        name: 'app-shop-courier-remittance-detail-page',
        redirect: (to) => ({
          name: 'app-shop-dropship-finance-hub-page',
          params: { tenantSlug: to.params.tenantSlug },
          query: { step: 'courier_remittance' },
        }),
      },
      {
        path: ':id',
        name: 'app-shop-dropship-order-detail-page',
        component: () => import('src/modules/shop_order/pages/DropshipOrderDetailPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/shop/dropship/:id/recipient-invoice-preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: guard('shop_order_mgmt'),
    children: [
      {
        path: '',
        name: 'app-shop-dropship-recipient-invoice-preview',
        component: () => import('src/modules/shop_order/pages/DropshipOrderRecipientInvoicePreviewPage.vue'),
      },
    ],
  },

  // Legacy redirects (Phase 9)
  {
    path: '/:tenantSlug?/app/commerce/shop',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      return `${tenantSlug}/app/shop/shops`;
    },
  },
  {
    path: '/:tenantSlug?/app/commerce/orders',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      return `${tenantSlug}/app/shop/orders`;
    },
  },
  {
    path: '/:tenantSlug?/app/commerce-shop/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      return `${tenantSlug}/app/shop/shops`;
    },
  },
  {
    path: '/:tenantSlug?/app/stores/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      return `${tenantSlug}/app/shop/shops`;
    },
  },
];

export default adminRoutes;
