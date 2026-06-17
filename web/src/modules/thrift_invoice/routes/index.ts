import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const thriftInvoiceRoutes: RouteRecordRaw[] = [
   {
      path: '/:tenantSlug?/app/thrift/invoices',
      component: () => import('layouts/AppLayout.vue'),
      beforeEnter: createAccessGuard({
         loginRoute: 'admin-login-page',
         requiredScope: 'app',
         allowedRoles: ['admin', 'staff', 'viewer'],
         requireTenantContext: true,
         requiredModule: 'thrift_invoice',
      }),
      children: [
         {
            path: '',
            name: 'thrift-invoice-page',
            component: () => import('../pages/ThriftInvoicePage.vue'),
            meta: {
               title: 'Thrift Invoices',
               headerTitle: 'Invoice Ledger',
            },
         },
      ],
   },
];

export default thriftInvoiceRoutes;
