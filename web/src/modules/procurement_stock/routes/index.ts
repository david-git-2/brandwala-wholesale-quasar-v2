import type { NavigationGuard, RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/workspace/submodules/auth/guards/accessGuard';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { canAccessModule } from 'src/modules/workspace/submodules/navigation/modulePermissions';
import type { ModuleKey } from 'src/modules/workspace/submodules/navigation/moduleRegistry';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  });

const PROCUREMENT_OVERVIEW_MODULE_KEYS = [
  'procurement_demand',
  'procurement_fulfill',
  'global_shipment',
  'global_stock',
  'global_stock_movement',
  'global_stock_location',
  'cargo_company',
  'shipment_progress_settings',
  'inventory',
] as const satisfies readonly ModuleKey[];

const procurementOverviewGuard: NavigationGuard = async (to, _from, next) => {
  const authStore = useAuthStore();
  const hasAnyProcurementAccess = PROCUREMENT_OVERVIEW_MODULE_KEYS.some((moduleKey) =>
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

  if (hasAnyProcurementAccess) {
    next();
    return;
  }

  const result = await guard('global_shipment')(to);
  if (result === true) {
    next();
    return;
  }
  if (result === false) {
    next(false);
    return;
  }
  next(result);
};

const withTenantSlug = (to: { params: { tenantSlug?: string | string[] } }, path: string) => {
  const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null;
  return tenantSlug ? `/${tenantSlug}${path}` : path;
};

const procurementStockRoutes: RouteRecordRaw[] = [
  // Legacy Redirects
  {
    path: '/app/global/shipment/:rest(.*)*',
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
    path: '/app/global/stock/:rest(.*)*',
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
    path: '/app/stock/:rest(.*)*',
    redirect: (to) => withTenantSlug(to, '/app/procurement/stock'),
  },
  {
    path: '/app/procurement/stock/allocate/:rest(.*)*',
    redirect: (to) => withTenantSlug(to, '/app/procurement/stock'),
  },
  {
    path: '/app/procurement/tenant-stock/:rest(.*)*',
    redirect: (to) => withTenantSlug(to, '/app/procurement/stock'),
  },

  // Active Routes
  {
    path: '/app/procurement',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-overview',
        component: () => import('../pages/ProcurementOverviewPage.vue'),
        beforeEnter: procurementOverviewGuard,
      },
    ],
  },
  {
    path: '/app/procurement/demand',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-demand',
        component: () => import('../pages/ProcurementDemandPage.vue'),
        beforeEnter: guard('procurement_demand'),
      },
      {
        path: 'document/:documentType/:documentId',
        name: 'app-procurement-demand-document',
        component: () => import('../pages/ProcurementDemandBuyDocumentPage.vue'),
        beforeEnter: guard('procurement_demand'),
      },
    ],
  },
  {
    path: '/app/procurement/fulfill/:rest(.*)*',
    redirect: (to) => {
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      return withTenantSlug(
        to,
        `/app/procurement/delivery-paper${rest ? `/${rest}` : ''}`,
      );
    },
  },
  {
    path: '/app/procurement/delivery-paper',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-fulfill',
        component: () => import('../pages/ProcurementFulfillPage.vue'),
        beforeEnter: guard('procurement_fulfill'),
        meta: { breadcrumb: 'Delivery paper' },
      },
      {
        path: 'group/:documentType/:documentId',
        name: 'app-procurement-fulfill-group',
        component: () => import('../pages/ProcurementFulfillGroupPage.vue'),
        beforeEnter: guard('procurement_fulfill'),
      },
      {
        path: 'paper/:paperId',
        name: 'app-procurement-fulfill-delivery-paper-page',
        component: () => import('../pages/DeliveryPaperDetailPage.vue'),
        beforeEnter: guard('procurement_fulfill'),
      },
    ],
  },
  {
    path: '/app/procurement/fulfill',
    redirect: (to) => withTenantSlug(to, '/app/procurement/delivery-paper'),
  },
  {
    path: '/app/procurement/shipment',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        redirect: (to) => withTenantSlug(to, '/app/procurement/shipment/list'),
      },
      {
        path: 'list',
        name: 'app-procurement-shipment-list',
        component: () => import('../pages/InboundShipmentListPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: 'overview',
        redirect: (to) => withTenantSlug(to, '/app/procurement'),
      },
      {
        path: ':id',
        name: 'app-procurement-shipment-details',
        component: () => import('../pages/ShipmentLineItemsV2Page.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/v2',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/items',
        name: 'app-procurement-shipment-items',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/items/v2',
        name: 'app-procurement-shipment-items-v2',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/lines',
        name: 'app-procurement-shipment-lines',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/add-catalog',
        name: 'app-procurement-shipment-add-catalog',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/rates',
        name: 'app-procurement-shipment-rates',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/rates-invoices',
        name: 'app-procurement-shipment-rates-invoices',
        redirect: (to) => withTenantSlug(to, `/app/procurement/shipment/${to.params.id}`),
      },
      {
        path: ':id/receive',
        name: 'app-procurement-shipment-receive',
        component: () => import('../pages/ReceiveShipmentPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/box',
        name: 'app-procurement-shipment-box',
        component: () => import('../pages/ShipmentBoxWeightPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/batch-code',
        name: 'app-procurement-shipment-batch-code',
        component: () => import('../pages/ShipmentBatchCodePage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/investor-investment',
        name: 'app-procurement-shipment-investor-investment',
        component: () => import('../pages/ShipmentInvestorInvestmentPage.vue'),
        beforeEnter: guard('investor_shipment_share'),
      },
    ],
  },
  {
    path: '/app/procurement/batch-code',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-batch-code-list',
        component: () => import('../pages/BatchCodeListPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':listId',
        name: 'app-procurement-batch-code-details',
        component: () => import('../pages/BatchCodeDetailsPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
    ],
  },
  {
    path: '/app/procurement/stock',
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
    path: '/app/procurement/movements',
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
    path: '/app/procurement/locations',
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
    path: '/app/procurement/cargo-companies',
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
    path: '/app/procurement/shipment-progress',
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
