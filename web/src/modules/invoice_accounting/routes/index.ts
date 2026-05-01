import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const invoiceAccountingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/invoice-accounting',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-invoice-accounting-page',
        component: () => import('../pages/AdminInvoiceAccountingPage.vue'),
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
        name: 'app-invoice-accounting-by-invoice-page',
        component: () => import('../pages/AdminInvoiceAccountingPage.vue'),
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

export default invoiceAccountingRoutes
