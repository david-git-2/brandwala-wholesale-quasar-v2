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
        component: () => import('src/modules/shop_order/pages/ShopsPage.vue'),
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

  // shop_permissions — Customer Access
  {
    path: '/:tenantSlug?/app/shop/customer-groups',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-customer-groups-page',
        component: () => import('src/modules/shop_order/pages/CustomerAccessPage.vue'),
        beforeEnter: guard('shop_permissions'),
      },
      {
        path: ':groupId/members',
        name: 'app-shop-customer-group-members-page',
        component: () => import('src/modules/shop_order/pages/CustomerGroupMembersPage.vue'),
        beforeEnter: guard('shop_permissions'),
      },
      {
        path: ':groupId/permissions',
        name: 'app-shop-customer-group-permissions-page',
        redirect: (to) => ({
          name: 'app-shop-customer-group-members-page',
          params: {
            tenantSlug: to.params.tenantSlug,
            groupId: to.params.groupId,
          },
        }),
      },
    ],
  },

  // shop_pricing — Shop Pricing (accessed per shop in P4)
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

  // shop_fulfillment — Fulfillment (app scope)
  {
    path: '/:tenantSlug?/app/shop/fulfillment',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-fulfillment-page',
        component: () => import('src/modules/shop_order/pages/ShopFulfillmentPage.vue'),
        beforeEnter: guard('shop_fulfillment'),
      },
    ],
  },

  // shop_dropship — Dropship Ops Desk (app scope)
  {
    path: '/:tenantSlug?/app/shop/dropship',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-dropship-orders-page',
        component: () => import('src/modules/shop_order/pages/DropshipOrdersPage.vue'),
        beforeEnter: guard('shop_dropship'),
      },
      {
        path: 'couriers',
        name: 'app-shop-dropship-couriers-page',
        component: () => import('src/modules/shop_order/pages/DropshipCouriersPage.vue'),
        beforeEnter: guard('shop_dropship'),
      },
      {
        path: 'ledger',
        name: 'app-shop-dropship-ledger-page',
        component: () => import('src/modules/shop_order/pages/DropshipLedgerPage.vue'),
        beforeEnter: guard('shop_dropship'),
      },
      {
        path: 'merchants',
        name: 'app-shop-dropship-merchants-page',
        component: () => import('src/modules/shop_order/pages/DropshipMerchantsPage.vue'),
        beforeEnter: guard('shop_dropship'),
      },
      {
        path: ':id',
        name: 'app-shop-dropship-order-detail-page',
        component: () => import('src/modules/shop_order/pages/DropshipOrderDetailPage.vue'),
        beforeEnter: guard('shop_dropship'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/shop/dropship/:id/recipient-invoice-preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: guard('shop_dropship'),
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
