import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const legacyGuard = createAccessGuard({
  loginRoute: 'admin-login-page',
  requiredScope: 'app',
  requireTenantContext: true,
  allowedRoles: ['admin', 'staff'],
  requiredModule: 'invoice',
})

const invoiceRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/invoices',
    redirect: (to) => ({
      name: 'app-global-invoices-page',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/invoices/billing-profiles',
    redirect: (to) => ({
      name: 'app-global-billing-profiles',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/invoices/brands',
    redirect: (to) => ({
      name: 'app-global-invoice-brands',
      params: { tenantSlug: to.params.tenantSlug },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/invoices/:invoiceId',
    redirect: (to) => ({
      name: 'app-global-invoice-details-page',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.invoiceId },
    }),
    beforeEnter: legacyGuard,
  },
  {
    path: '/:tenantSlug?/app/invoices/:invoiceId/preview',
    redirect: (to) => ({
      name: 'app-global-invoice-preview',
      params: { tenantSlug: to.params.tenantSlug, id: to.params.invoiceId },
    }),
    beforeEnter: legacyGuard,
  },
]

export default invoiceRoutes
