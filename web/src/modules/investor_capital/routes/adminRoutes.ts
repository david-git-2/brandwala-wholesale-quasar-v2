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

const investorCapitalAdminRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/capital/profiles',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-capital-profiles-page',
        component: () =>
          import('src/modules/investor_capital/pages/admin/InvestorProfilesPage.vue'),
        beforeEnter: guard('investor_profiles'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/capital/ledger',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-capital-ledger-page',
        component: () => import('src/modules/investor_capital/pages/admin/CapitalLedgerPage.vue'),
        beforeEnter: guard('investor_capital_ledger'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/capital/shipments',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-capital-shipments-page',
        component: () =>
          import('src/modules/investor_capital/pages/admin/ShipmentAllocationsPage.vue'),
        beforeEnter: guard('investor_shipment_share'),
      },
      {
        path: ':id',
        name: 'app-capital-shipment-details-page',
        component: () =>
          import('src/modules/investor_capital/pages/admin/ShipmentAllocationDetailsPage.vue'),
        beforeEnter: guard('investor_shipment_share'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/investors/profile',
    redirect: (to) => ({
      name: 'app-capital-profiles-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: guard('investor_profiles'),
  },
  {
    path: '/:tenantSlug?/app/investors/transactions',
    redirect: (to) => ({
      name: 'app-capital-ledger-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: guard('investor_capital_ledger'),
  },
  {
    path: '/:tenantSlug?/app/investors/shipments',
    redirect: (to) => ({
      name: 'app-capital-shipments-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: guard('investor_shipment_share'),
  },
  {
    path: '/:tenantSlug?/app/investors/shipments/:id',
    redirect: (to) => ({
      name: 'app-capital-shipment-details-page',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
    }),
    beforeEnter: guard('investor_shipment_share'),
  },
];

export default investorCapitalAdminRoutes;
