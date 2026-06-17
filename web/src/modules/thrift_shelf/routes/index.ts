import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftShelfRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/shelves',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_shelf',
      }),
      children: [
         {
            path: '',
            name: 'thrift-shelf-page',
            component: () => import('../pages/ThriftShelfPage.vue'),
            meta: {
               title: 'Thrift Shelves',
               headerTitle: 'Shelf Physical Locations',
            },
         },
      ],
   },
];

export default thriftShelfRoutes;
