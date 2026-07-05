import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const legacyGuard = createAccessGuard({
  loginRoute: 'admin-login-page',
  requiredScope: 'app',
  requireTenantContext: true,
  allowedRoles: ['admin', 'staff'],
  requiredModule: 'investor',
})

const investorRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/investors/profile',
    redirect: (to) => ({
      name: 'app-capital-profiles-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/investors/transactions',
    redirect: (to) => ({
      name: 'app-capital-ledger-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/investors/shipments',
    redirect: (to) => ({
      name: 'app-capital-shipments-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/investors/shipments/:id',
    redirect: (to) => ({
      name: 'app-capital-shipment-details-page',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.id },
    }),
    beforeEnter: legacyGuard,
  },
]

export default investorRoutes
