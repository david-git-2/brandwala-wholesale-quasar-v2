import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import { SHIPMENT_ROUTE_SEGMENT } from '../utils/shipmentPaths'

const shipmentGuard = createAccessGuard({
  loginRoute: 'admin-login-page',
  requiredScope: 'app',
  requireTenantContext: true,
  allowedRoles: ['admin', 'staff'],
  requiredModule: 'global_shipment',
})

const shipmentRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/shipment/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug =
        typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : ''

      return tenantSlug
        ? `/${tenantSlug}/app/${SHIPMENT_ROUTE_SEGMENT}${rest ? `/${rest}` : ''}`
        : `/app/${SHIPMENT_ROUTE_SEGMENT}${rest ? `/${rest}` : ''}`
    },
  },
  {
    path: `/:tenantSlug?/app/${SHIPMENT_ROUTE_SEGMENT}`,
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-shipment-page',
        component: () => import('../pages/AdminShipmentPage.vue'),
        beforeEnter: shipmentGuard,
      },
      {
        path: ':id',
        name: 'app-shipment-details-page',
        component: () => import('../pages/AdminShipmentDetailsPage.vue'),
        beforeEnter: shipmentGuard,
      },
      {
        path: ':id/batch-code-pc',
        name: 'app-shipment-batch-code-pc-page',
        component: () => import('../pages/AdminShipmentBatchCodePage.vue'),
        beforeEnter: shipmentGuard,
      },
    ],
  },
]

export default shipmentRoutes
