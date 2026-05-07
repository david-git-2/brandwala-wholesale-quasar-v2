import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const accountingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/accounting',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-accounting-page',
        component: () => import('../pages/AdminAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'accounting',
        }),
      },
      {
        path: 'invoice',
        name: 'app-accounting-invoice-page',
        component: () => import('../pages/AdminInvoiceAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'accounting',
        }),
      },
      {
        path: 'shipment',
        name: 'app-accounting-shipment-page',
        component: () => import('../pages/AdminShipmentAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'accounting',
        }),
      },
      {
        path: 'shipment/:id',
        name: 'app-accounting-shipment-details-page',
        component: () => import('../pages/AdminShipmentAccountingDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'accounting',
        }),
      },
    ],
  },
]

export default accountingRoutes
