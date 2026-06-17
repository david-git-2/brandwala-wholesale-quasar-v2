import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/shipments',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_shipment',
      }),
      children: [
         {
            path: '',
            name: 'thrift-shipments-page',
            component: () => import('../pages/ThriftShipmentPage.vue'),
            meta: {
               title: 'Thrift Shipments',
               headerTitle: 'Thrift Shipments',
            },
         },
      ],
   },
   {
      path: '/:tenantSlug?/app/thrift/boxes',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_box',
      }),
      children: [
         {
            path: '',
            name: 'thrift-boxes-page',
            component: () => import('../pages/ThriftBoxPage.vue'),
            meta: {
               title: 'Thrift Boxes',
               headerTitle: 'Thrift Boxes',
            },
         },
      ],
   },
];

export default thriftRoutes;
