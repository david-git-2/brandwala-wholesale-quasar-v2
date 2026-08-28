import type { NavigationGuard, RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { canAccessModule } from 'src/modules/navigation/modulePermissions';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  });

const PROCUREMENT_OVERVIEW_MODULE_KEYS = [
  'procurement_demand',
  'global_shipment',
  'global_stock',
  'global_stock_movement',
  'global_stock_location',
  'cargo_company',
  'shipment_progress_settings',
  'inventory',
] as const satisfies readonly ModuleKey[];

const procurementOverviewGuard: NavigationGuard = (to, from, next) => {
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

  return guard('global_shipment')(to, from, next);
};

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
    path: '/:tenantSlug?/app/procurement',
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
    path: '/:tenantSlug?/app/procurement/demand',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-demand',
        component: () => import('../pages/ProcurementDemandPage.vue'),
        beforeEnter: guard('procurement_demand'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/shipment',
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
