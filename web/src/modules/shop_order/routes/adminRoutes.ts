import type { NavigationGuard, RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { canAccessModule } from 'src/modules/navigation/modulePermissions';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext';

const SHOP_OVERVIEW_MODULE_KEYS = [
  'shop_config',
  'shop_category',
  'shop_permissions',
  'shop_pricing',
  'shop_order_mgmt',
  'shop_shipping',
] as const satisfies readonly ModuleKey[];

const SHOP_STORE_OVERVIEW_MODULE_KEYS = [
  'shop_config',
  'shop_category',
  'customer',
  'shop_pricing',
] as const satisfies readonly ModuleKey[];

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

const shopOverviewGuard: NavigationGuard = async (to, from) => {
  const authStore = useAuthStore();
  const hasAnyShopAccess = SHOP_OVERVIEW_MODULE_KEYS.some((moduleKey) =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    }),
  );

  if (hasAnyShopAccess) {
    return true;
  }

  return guard('shop_order_mgmt')(to);
};

const shopStoreOverviewGuard: NavigationGuard = async (to, from) => {
  const authStore = useAuthStore();
  const hasAnyStoreAccess = SHOP_STORE_OVERVIEW_MODULE_KEYS.some((moduleKey) =>
    canAccessModule({
      scope: authStore.scope,
      tenantId: authStore.tenantId,
      customerGroupId: authStore.customerGroupId,
      role: authStore.matchedRole,
      moduleKey,
      activeModuleKeys: authStore.activeModuleKeys,
      effectiveGrants: authStore.access?.effectiveGrants,
      isAdmin: authStore.access?.isAdmin,
    }),
  );

  if (hasAnyStoreAccess) {
    return true;
  }

  return guard('shop_config')(to);
};

const adminRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/shop',
    component: () => import('layouts/AppLayout.vue'),
    name: 'admin-shop-settings',
    children: [
      {
        path: '',
        name: 'app-shop-overview-page',
        component: () => import('src/modules/shop_order/pages/ShopOrderOverviewPage.vue'),
        beforeEnter: shopOverviewGuard,
      },
      {
        path: 'overview',
        redirect: (to) => {
          const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
          return `${tenantSlug}/app/shop`;
        },
      },
      {
        path: 'roles',
        name: 'admin-shop-roles',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to);
          return tenantSlug
            ? `/${tenantSlug}/app/access-control/roles`
            : '/app/access-control/roles';
        },
      },
      {
        path: 'roles/:id/grants',
        name: 'admin-shop-role-grants',
        redirect: (to) => {
          const tenantSlug = getTenantSlugFromRoute(to);
          const id = String(to.params.id);
          return tenantSlug
            ? `/${tenantSlug}/app/access-control/roles/${id}/grants`
            : `/app/access-control/roles/${id}/grants`;
        },
      },
    ],
  },

  // shop_config — Shops
  {
    path: '/:tenantSlug?/app/shop/shops',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-shops-page',
        component: () => import('src/modules/shop_order/pages/ShopStoreOverviewPage.vue'),
        beforeEnter: shopStoreOverviewGuard,
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
      name: 'app-customers-list',
      params: { tenantSlug: to.params.tenantSlug },
    }),
  },
  {
    path: '/:tenantSlug?/app/shop/customer-groups/:pathMatch(.*)*',
    redirect: (to) => ({
      name: 'app-customers-list',
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

  {
    path: '/:tenantSlug?/app/shop/dropship-management',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shop-dropship-management-page',
        component: () => import('src/modules/shop_order/pages/DropshipManagementPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
      {
        path: ':id',
        name: 'app-shop-dropship-management-detail-page',
        component: () => import('src/modules/shop_order/pages/DropshipManagementDetailPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
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
        path: ':id/v2/ready-for-pickup',
        redirect: (to) => ({
          name: 'app-shop-dropship-order-detail-ready-for-pickup-page',
          params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
        }),
      },
      {
        path: ':id/v2/processing',
        redirect: (to) => ({
          name: 'app-shop-dropship-order-detail-processing-page',
          params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
        }),
      },
      {
        path: ':id/v2',
        redirect: (to) => ({
          name: 'app-shop-dropship-order-detail-page',
          params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
        }),
      },
      {
        path: ':id/ready-for-pickup',
        name: 'app-shop-dropship-order-detail-ready-for-pickup-page',
        component: () =>
          import('src/modules/shop_order/pages/DropshipOrderDetailV2ReadyForPickupPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
      {
        path: ':id/processing',
        name: 'app-shop-dropship-order-detail-processing-page',
        component: () =>
          import('src/modules/shop_order/pages/DropshipOrderDetailV2ProcessingPage.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
      {
        path: ':id',
        name: 'app-shop-dropship-order-detail-page',
        component: () => import('src/modules/shop_order/pages/DropshipOrderDetailV2Page.vue'),
        beforeEnter: guard('shop_order_mgmt'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/shop/dropship/:id/v2/customer-invoice-preview',
    redirect: (to) => ({
      name: 'app-shop-dropship-order-customer-invoice-preview',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
    }),
  },
  {
    path: '/:tenantSlug?/app/shop/dropship/:id/customer-invoice-preview',
    component: () => import('layouts/ExternalLayout.vue'),
    beforeEnter: guard('shop_order_mgmt'),
    children: [
      {
        path: '',
        name: 'app-shop-dropship-order-customer-invoice-preview',
        component: () =>
          import('src/modules/shop_order/pages/DropshipOrderDetailV2CustomerInvoicePreviewPage.vue'),
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
      return `${tenantSlug}/app/shop`;
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
      return `${tenantSlug}/app/shop`;
    },
  },
  {
    path: '/:tenantSlug?/app/stores/:catchAll(.*)*',
    redirect: (to) => {
      const tenantSlug = to.params.tenantSlug ? `/${String(to.params.tenantSlug)}` : '';
      return `${tenantSlug}/app/shop`;
    },
  },
];

export default adminRoutes;
