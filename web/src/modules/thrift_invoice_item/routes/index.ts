import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftInvoiceItemRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/invoice-items',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_invoice_item',
      }),
      children: [
         {
            path: '',
            name: 'thrift-invoice-item-page',
            component: () => import('../pages/ThriftInvoiceItemPage.vue'),
            meta: {
               title: 'Thrift Invoice Items',
               headerTitle: 'Sales Item Breakdown',
            },
         },
      ],
   },
];

export default thriftInvoiceItemRoutes;
