import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftStockRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/stocks',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_stock',
      }),
      children: [
         {
            path: '',
            name: 'thrift-stock-page',
            component: () => import('../pages/ThriftStockPage.vue'),
            meta: {
               title: 'Thrift Stocks',
               headerTitle: 'Stock Catalog',
            },
         },
      ],
   },
];

export default thriftStockRoutes;
