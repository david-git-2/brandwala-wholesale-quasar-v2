import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftPricingRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/pricing',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_pricing',
      }),
      children: [
         {
            path: '',
            name: 'thrift-pricing-page',
            component: () => import('../pages/ThriftPricingPage.vue'),
            meta: {
               title: 'Thrift Pricing',
               headerTitle: 'Pricing Grid',
            },
         },
      ],
   },
];

export default thriftPricingRoutes;
