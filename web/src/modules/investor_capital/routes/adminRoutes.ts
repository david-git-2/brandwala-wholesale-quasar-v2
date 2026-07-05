import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry'
import {
  getAppRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const guard = (requiredModule: ModuleKey, allowedRoles: ('admin' | 'staff')[] = ['admin', 'staff']) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    allowedRoles,
    requiredModule,
    validateAccess: ({ authStore, to }) => {
      const selectedTenantSlug = authStore.selectedTenant?.slug ?? null

      if (!selectedTenantSlug) {
        return true
      }

      const routeTenantSlug = getTenantSlugFromRoute(to)

      if (routeTenantSlug === selectedTenantSlug) {
        return true
      }

      return getAppRouteLocation(to, selectedTenantSlug)
    },
  })

const investorCapitalAdminRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/capital/profiles',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-capital-profiles-page',
        component: () => import('src/modules/investor_capital/pages/admin/InvestorProfilesPage.vue'),
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
        component: () => import('src/modules/investor_capital/pages/admin/ShipmentAllocationsPage.vue'),
        beforeEnter: guard('investor_shipment_share'),
      },
      {
        path: ':id',
        name: 'app-capital-shipment-details-page',
        component: () => import('src/modules/investor_capital/pages/admin/ShipmentAllocationDetailsPage.vue'),
        beforeEnter: guard('investor_shipment_share'),
      },
    ],
  },
]

export default investorCapitalAdminRoutes
