import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const shipmentRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/shipment',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shipment-page',
        component: () => import('../pages/AdminShipmentPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'shipment',
        }),
      },
      {
        path: ':id',
        name: 'app-shipment-details-page',
        component: () => import('../pages/AdminShipmentDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'shipment',
        }),
      },
      {
        path: ':id/orders',
        name: 'app-shipment-order-list-page',
        component: () => import('../pages/AdminOrderList.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin', 'staff'],
          requiredModule: 'shipment',
        }),
      },

    ],
  },
]

export default shipmentRoutes
