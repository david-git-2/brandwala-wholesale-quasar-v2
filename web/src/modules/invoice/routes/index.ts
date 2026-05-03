import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const invoiceRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/invoices',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-invoice-page',
        component: () => import('../pages/AdminInvoicePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'invoice',
        }),
      },
      {
        path: ':invoiceId',
        name: 'app-invoice-details-page',
        component: () => import('../pages/AdminInvoiceDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'invoice',
        }),
      },
      {
        path: 'billing-profiles',
        name: 'app-billing-profiles-page',
        component: () => import('../pages/AdminBillingProfilesPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'invoice',
        }),
      },
    ],
  },
]

export default invoiceRoutes
