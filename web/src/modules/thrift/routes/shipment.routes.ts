import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftGuard = {
  loginRoute: 'admin-login-page' as const,
  requiredScope: 'app' as const,
  allowedRoles: ['admin', 'staff'] as const,
  requireTenantContext: true,
};

const routes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/thrift/shipments',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      ...thriftGuard,
      requiredModule: 'thrift_shipment',
    }),
    children: [
      {
        path: '',
        name: 'thrift-shipments-page',
        component: () => import('../shipment/pages/ThriftShipmentPage.vue'),
        meta: {
          title: 'Thrift Shipments',
          headerTitle: 'Thrift Shipments',
        },
      },
    ],
  },
];

export default routes;
