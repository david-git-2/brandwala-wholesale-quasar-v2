import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  });

const withTenantSlug = (to: { params: { tenantSlug?: string | string[] } }, path: string) => {
  const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null;
  return tenantSlug ? `/${tenantSlug}${path}` : path;
};

const procurementStockRoutes: RouteRecordRaw[] = [
  // Legacy Redirects
  {
    path: '/:tenantSlug?/app/global/shipment/:rest(.*)*',
    redirect: (to) => {
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      return withTenantSlug(
        to,
        `/app/procurement/shipment${rest ? `/${rest}` : ''}`,
      );
    },
  },
  {
    path: '/:tenantSlug?/app/global/stock/:rest(.*)*',
    redirect: (to) => {
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      return withTenantSlug(to, `/app/procurement/stock${rest ? `/${rest}` : ''}`);
    },
  },
  {
    path: '/:tenantSlug?/app/stock/:rest(.*)*',
    redirect: (to) => withTenantSlug(to, '/app/procurement/child-stock'),
  },
  {
    path: '/:tenantSlug?/app/procurement/stock/allocate/:rest(.*)*',
    redirect: (to) => withTenantSlug(to, '/app/procurement/stock'),
  },
  {
    path: '/:tenantSlug?/app/procurement/tenant-stock/:rest(.*)*',
    redirect: (to) => withTenantSlug(to, '/app/procurement/child-stock'),
  },

  // Active Routes
  {
    path: '/:tenantSlug?/app/procurement/shipment',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-shipment-list',
        component: () => import('../pages/InboundShipmentListPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id',
        name: 'app-procurement-shipment-details',
        component: () => import('../pages/ShipmentOverviewPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/items',
        name: 'app-procurement-shipment-items',
        component: () => import('../pages/ShipmentLineItemsPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/lines',
        name: 'app-procurement-shipment-lines',
        component: () => import('../pages/ShipmentLineItemsPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/add-catalog',
        name: 'app-procurement-shipment-add-catalog',
        component: () => import('../pages/ShipmentAddCatalogPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/rates',
        name: 'app-procurement-shipment-rates',
        component: () => import('../pages/ShipmentRatesPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/adjust',
        name: 'app-procurement-shipment-adjust',
        component: () => import('../pages/ShipmentAdjustPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/settle',
        name: 'app-procurement-shipment-settle',
        component: () => import('../pages/ShipmentPayeeSettlePage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/rates-invoices',
        name: 'app-procurement-shipment-rates-invoices',
        component: () => import('../pages/ShipmentRatesInvoicesPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/receive',
        name: 'app-procurement-shipment-receive',
        component: () => import('../pages/ReceiveShipmentPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/stock',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-stock-list',
        component: () => import('../pages/WarehouseStockListPage.vue'),
        beforeEnter: guard('global_stock'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/movements',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-movements',
        component: () => import('../pages/StockMovementsPage.vue'),
        beforeEnter: guard('global_stock_movement'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/locations',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-locations',
        component: () => import('../pages/StockLocationsPage.vue'),
        beforeEnter: guard('global_stock_location'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/cargo-companies',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-cargo-companies',
        component: () => import('../pages/CargoCompaniesPage.vue'),
        beforeEnter: guard('cargo_company'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/child-stock',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-child-stock',
        component: () => import('../pages/ChildStockPage.vue'),
        beforeEnter: guard('inventory'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/shipment-progress',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-shipment-progress-settings',
        component: () => import('../pages/ShipmentProgressSettingsPage.vue'),
        beforeEnter: guard('shipment_progress_settings'),
      },
      {
        path: ':flowId',
        name: 'app-procurement-shipment-progress-flow',
        component: () => import('../pages/ShipmentProgressSettingsPage.vue'),
        beforeEnter: guard('shipment_progress_settings'),
      },
    ],
  },
  // Public tracking — no auth guard, uses ExternalLayout
  {
    path: '/track/shipment/:token',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'public-shipment-tracking',
        component: () => import('../pages/PublicShipmentTrackingPage.vue'),
      },
    ],
  },
];

export default procurementStockRoutes;
