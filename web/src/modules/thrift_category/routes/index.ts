import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftCategoryRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/categories',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_category',
      }),
      children: [
         {
            path: '',
            name: 'thrift-category-page',
            component: () => import('../pages/ThriftCategoryPage.vue'),
            meta: {
               title: 'Thrift Categories',
               headerTitle: 'Category Classification',
            },
         },
      ],
   },
];

export default thriftCategoryRoutes;
