import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftTypeRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/types',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_type',
      }),
      children: [
         {
            path: '',
            name: 'thrift-type-page',
            component: () => import('../pages/ThriftTypePage.vue'),
            meta: {
               title: 'Thrift Types',
               headerTitle: 'Style Classifications',
            },
         },
      ],
   },
];

export default thriftTypeRoutes;
